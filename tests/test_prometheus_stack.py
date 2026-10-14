"""prometheus-stack puts every metrics endpoint behind a guard. Prometheus and
Alertmanager listen on 127.0.0.1 behind a kube-rbac-proxy sidecar,
node-exporter runs its subchart's kube-rbac-proxy, and kube-state-metrics
serves TLS behind its own --auth-filter. Every guard serves a certificate from
one cert-manager CA, and Prometheus scrapes and alerts through them with its
ServiceAccount token. The wiring names objects by the default release names,
so validate.yaml refuses anything that renames them."""
import functools
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))

import yaml  # noqa: E402

from render import container, find, render, run, template  # noqa: E402

CHART = os.path.join(os.path.dirname(__file__), "..", "prometheus-stack")
RELEASE = "prometheus-stack"
NS = "monitoring"
PROM = "prometheus-stack-kube-prom-prometheus"
AM = "prometheus-stack-kube-prom-alertmanager"
KSM = "prometheus-stack-kube-state-metrics"
NE = "prometheus-stack-prometheus-node-exporter"
TOKEN = "/var/run/secrets/kubernetes.io/serviceaccount/token"
TLS = {PROM: f"{PROM}-tls", AM: f"{AM}-tls", KSM: f"{KSM}-tls", NE: f"{NE}-tls"}
CA = "prometheus-stack-kube-rbac-proxy-ca"

# Extra helm arguments for every render, e.g. ["-f", "site-values.yaml"] to run
# the checks against a deployment's own values.
EXTRA = []


@functools.lru_cache(maxsize=None)
def _docs(extra):
    return render(RELEASE, CHART, NS, *EXTRA, *extra)


def docs(*extra):
    return _docs(extra)


def helm(release=RELEASE, namespace=NS, *extra):
    return template(release, CHART, namespace, *EXTRA, *extra)


def check_prometheus():
    spec = find(docs(), "Prometheus", PROM)["spec"]
    assert spec["listenLocal"] is True
    c = container(spec, "kube-rbac-proxy")
    assert "--upstream=http://127.0.0.1:9090/" in c["args"], c["args"]
    assert "--secure-listen-address=:9091" in c["args"], c["args"]
    ports = [{k: p[k] for k in ("name", "containerPort")} for p in c["ports"]]
    assert {"name": "http-web", "containerPort": 9091} in ports, ports
    vols = {v["name"]: v for v in spec["volumes"]}
    assert vols["kube-rbac-proxy-tls"]["secret"]["secretName"] == TLS[PROM]
    am = spec["alerting"]["alertmanagers"]
    assert len(am) == 1 and am[0]["name"] == AM and am[0]["scheme"] == "https", am
    assert am[0]["bearerTokenFile"] == TOKEN
    assert am[0]["tlsConfig"]["ca"]["secret"] == {"name": TLS[AM], "key": "ca.crt"}


def check_prometheus_image_has_shell():
    # With listenLocal the operator execs `sh -c 'curl ... || wget ...'` for
    # the startup, readiness and liveness probes. A -distroless image has no
    # shell, so Prometheus would never get Ready.
    spec = find(docs(), "Prometheus", PROM)["spec"]
    if spec.get("listenLocal"):
        assert "distroless" not in spec["image"], f"listenLocal needs a shell in {spec['image']}"


def check_alertmanager():
    spec = find(docs(), "Alertmanager", AM)["spec"]
    assert spec["listenLocal"] is True
    c = container(spec, "kube-rbac-proxy")
    assert "--upstream=http://127.0.0.1:9093/" in c["args"], c["args"]
    assert "--secure-listen-address=:9095" in c["args"], c["args"]
    vols = {v["name"]: v for v in spec["volumes"]}
    assert vols["kube-rbac-proxy-tls"]["secret"]["secretName"] == TLS[AM]


def check_services():
    prom = [p["port"] for p in find(docs(), "Service", PROM)["spec"]["ports"]]
    assert prom == [9091], f"{PROM} ports {prom}: 9090 and reloader-web must be gone"
    am = [p["port"] for p in find(docs(), "Service", AM)["spec"]["ports"]]
    assert 9095 in am and 9093 not in am, am


def check_exporters():
    ksm = find(docs(), "Deployment", KSM)["spec"]["template"]["spec"]
    names = [c["name"] for c in ksm["containers"]]
    assert names == ["kube-state-metrics"], f"KSM runs its own auth filter, no sidecar: {names}"
    c = container(ksm, "kube-state-metrics")
    assert "--auth-filter" in c["args"], c["args"]
    assert "--tls-config=/etc/kube-state-metrics/web-config.yaml" in c["args"], c["args"]
    assert {"http", "metrics"} <= {p["name"] for p in c["ports"]}, c["ports"]
    for probe in ("livenessProbe", "readinessProbe"):
        assert c[probe]["httpGet"]["scheme"] == "HTTPS", f"{probe} scheme"
    vols = {v["name"]: v for v in ksm["volumes"]}
    assert any(v.get("secret", {}).get("secretName") == TLS[KSM] for v in vols.values()), vols
    cms = [v["configMap"]["name"] for v in vols.values() if "configMap" in v]
    assert f"{KSM}-web-config" in cms, cms
    mounts = {m["mountPath"] for m in c["volumeMounts"]}
    assert {"/etc/tls/private", "/etc/kube-state-metrics"} <= mounts, mounts
    wc = yaml.safe_load(find(docs(), "ConfigMap", f"{KSM}-web-config")["data"]["web-config.yaml"])
    assert wc == {"tls_server_config": {"cert_file": "/etc/tls/private/tls.crt",
                                         "key_file": "/etc/tls/private/tls.key"}}, wc
    ne = find(docs(), "DaemonSet", NE)["spec"]["template"]["spec"]
    assert ne["hostNetwork"] is True
    krp = container(ne, "kube-rbac-proxy")
    assert any(a.startswith("--tls-cert-file=") for a in krp["args"]), krp["args"]
    assert any(v.get("secret", {}).get("secretName") == TLS[NE] for v in ne["volumes"])


def check_guard_images():
    # The Prometheus and Alertmanager sidecars are spelled out in values.yaml,
    # node-exporter's comes from its subchart; all three run one kube-rbac-proxy.
    images = {
        "prometheus": container(find(docs(), "Prometheus", PROM)["spec"], "kube-rbac-proxy")["image"],
        "alertmanager": container(find(docs(), "Alertmanager", AM)["spec"], "kube-rbac-proxy")["image"],
        "node-exporter": container(find(docs(), "DaemonSet", NE)["spec"]["template"]["spec"], "kube-rbac-proxy")["image"],
    }
    assert len(set(images.values())) == 1, f"guards run different images: {images}"
    for c in find(docs(), "Deployment", KSM)["spec"]["template"]["spec"]["containers"]:
        assert "kube-rbac-proxy" not in c["image"], c


def check_service_monitors():
    for name, guarded in ((PROM, "http-web"), (AM, "http-web"), (KSM, "http"), (NE, "http-metrics")):
        eps = [e for e in find(docs(), "ServiceMonitor", name)["spec"]["endpoints"] if e["port"] == guarded]
        assert len(eps) == 1, f"ServiceMonitor {name}: endpoints on {guarded}: {len(eps)}"
        e = eps[0]
        assert e.get("scheme") == "https", f"{name}: scheme {e.get('scheme')}"
        assert e.get("bearerTokenFile") == TOKEN, f"{name}: bearerTokenFile"
        assert e["tlsConfig"]["ca"]["secret"] == {"name": TLS[name], "key": "ca.crt"}, f"{name}: ca"
        assert e["tlsConfig"]["serverName"] == f"{name}.{NS}.svc", f"{name}: serverName"
    ports = [e["port"] for e in find(docs(), "ServiceMonitor", KSM)["spec"]["endpoints"]]
    assert ports == ["http"], f"KSM endpoints {ports}"
    for name in (PROM, AM):
        eps = find(docs(), "ServiceMonitor", name)["spec"]["endpoints"]
        for e in eps:
            if e["port"] == "reloader-web":
                drops = [r for r in e.get("relabelings", []) if r.get("action") == "drop"
                         and r.get("sourceLabels") == ["__meta_kubernetes_endpoint_port_name"]
                         and re.fullmatch(r["regex"], "reloader-web")]
                assert drops, f"{name}: reloader-web endpoint is not dropped"
            if e["port"] == "http-web":
                assert not any(r.get("action") == "drop" and re.fullmatch(r["regex"], "http-web")
                               for r in e.get("relabelings", [])), f"{name}: http-web would be dropped"


def check_probe_ports():
    # kubelet resolves a named probe port against the probed container's own ports.
    pods = [(f"{d['kind']}/{d['metadata']['name']}", d["spec"]["template"]["spec"])
            for d in docs() if d["kind"] in ("Deployment", "DaemonSet")]
    pods += [(f"{d['kind']}/{d['metadata']['name']}", d["spec"])
             for d in docs() if d["kind"] in ("Prometheus", "Alertmanager")]
    for label, spec in pods:
        for c in spec.get("containers", []) + spec.get("initContainers", []):
            declared = {p["name"] for p in c.get("ports", []) if "name" in p}
            for probe in ("readinessProbe", "livenessProbe", "startupProbe"):
                pr = c.get(probe, {})
                port = pr.get("httpGet", pr.get("tcpSocket", {})).get("port")
                if isinstance(port, str):
                    assert port in declared, (
                        f"{label}/{c['name']} {probe} targets port {port!r}, "
                        f"the container declares {sorted(declared)}")


def check_tls_server_names():
    certs = {d["spec"]["secretName"]: d["spec"] for d in docs() if d["kind"] == "Certificate"}
    assert certs[CA]["isCA"] is True
    for name, secret in TLS.items():
        cert = certs[secret]
        assert cert["issuerRef"] == {"name": CA, "kind": "Issuer"}, cert["issuerRef"]
        assert f"{name}.{NS}.svc" in cert["dnsNames"], f"{secret}: {cert['dnsNames']}"
    find(docs(), "Issuer", CA)


def allows(rules, resource, name, verb):
    return any("monitoring.coreos.com" in r.get("apiGroups", [])
               and resource in r.get("resources", [])
               and name in r.get("resourceNames", [name])
               and (verb in r.get("verbs", []) or "*" in r.get("verbs", []))
               for r in rules)


def check_rbac():
    rules = find(docs(), "ClusterRole", PROM)["rules"]
    # kube-rbac-proxy asks get for a GET and create for a POST.
    assert allows(rules, "prometheuses/api", PROM, "get"), f"cannot scrape itself: {rules}"
    assert allows(rules, "alertmanagers/api", AM, "get"), f"cannot scrape Alertmanager: {rules}"
    assert allows(rules, "alertmanagers/api", AM, "create"), f"cannot send alerts: {rules}"
    # A POST through its own guard reaches /-/reload and /-/quit.
    assert not allows(rules, "prometheuses/api", PROM, "create"), f"may POST to itself: {rules}"
    flat = [r for rule in rules for r in rule.get("resources", [])]
    assert f"services/{NE}" in flat, flat
    assert any("/metrics" in r.get("nonResourceURLs", []) and "get" in r["verbs"] for r in rules), rules
    ksm_rules = find(docs(), "ClusterRole", KSM)["rules"]
    for group, res in (("authentication.k8s.io", "tokenreviews"), ("authorization.k8s.io", "subjectaccessreviews")):
        assert any(group in r.get("apiGroups", []) and res in r.get("resources", []) and "create" in r["verbs"]
                   for r in ksm_rules), f"KSM ClusterRole lacks {res} create"
    crb = find(docs(), "ClusterRoleBinding", "prometheus-stack-kube-rbac-proxy-auth-delegator")
    assert crb["roleRef"]["name"] == "system:auth-delegator"
    assert {(s["name"], s["namespace"]) for s in crb["subjects"]} == {(PROM, NS), (AM, NS)}


def check_names():
    for cr, kind, resource in ((PROM, "Prometheus", "prometheuses"), (AM, "Alertmanager", "alertmanagers")):
        cm = find(docs(), "ConfigMap", f"{cr}-kube-rbac-proxy")
        attrs = yaml.safe_load(cm["data"]["config.yaml"])["authorization"]["resourceAttributes"]
        assert attrs == {"apiGroup": "monitoring.coreos.com", "resource": resource, "subresource": "api",
                         "namespace": NS, "name": cr}, attrs
        sa = find(docs(), kind, cr)["spec"].get("serviceAccountName")
        assert sa == cr, f"{kind} runs as {sa}, the auth-delegator binding names {cr}"


def check_external_urls():
    assert find(docs(), "Prometheus", PROM)["spec"]["externalUrl"] == f"https://{PROM}.{NS}.svc:9091"
    assert find(docs(), "Alertmanager", AM)["spec"]["externalUrl"] == f"https://{AM}.{NS}.svc:9095"


def check_validate_release():
    for release, namespace in (("other", NS), (RELEASE, "observability")):
        r = helm(release, namespace)
        assert r.returncode != 0 and "prometheus-stack" in r.stderr, (
            f"{release}/{namespace} should fail: {r.stderr[:200]}")


def check_validate_overrides():
    keys = ["fullnameOverride", "nameOverride", "cleanPrometheusOperatorObjectNames", "namespaceOverride"]
    keys += [f"{sub}.{key}" for sub in ("kube-state-metrics", "prometheus-node-exporter")
             for key in ("fullnameOverride", "nameOverride")]
    for key in keys:
        r = helm(RELEASE, NS, "--set", f"kube-prometheus-stack.{key}=foo")
        assert r.returncode != 0 and key in r.stderr, f"{key} should fail: {r.stderr[:200]}"


def check_disabled():
    r = helm(RELEASE, NS, "--set", "kube-prometheus-stack.enabled=false")
    assert r.returncode == 0, r.stderr
    kinds = {d["kind"] for d in yaml.safe_load_all(r.stdout) if d}
    bad = kinds & {"Certificate", "Issuer", "ClusterRoleBinding", "ConfigMap"}
    assert not bad, f"disabled subchart still renders {bad}"


CHECKS = [
    check_prometheus, check_prometheus_image_has_shell, check_alertmanager, check_services,
    check_exporters, check_guard_images, check_service_monitors, check_probe_ports,
    check_tls_server_names, check_rbac, check_names, check_external_urls,
    check_validate_release, check_validate_overrides, check_disabled,
]

if __name__ == "__main__":
    run(CHECKS)
