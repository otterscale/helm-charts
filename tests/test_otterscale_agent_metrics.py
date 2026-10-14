"""otterscale-agent reaches Prometheus through prometheus-stack's kube-rbac-proxy:
over https with its own ServiceAccount token, verifying the proxy against the
CA in prometheus-stack's TLS Secret. Its defaults must name what
prometheus-stack actually renders, and the chart grants exactly what that
path needs."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from render import find, render, run, template  # noqa: E402

TESTS = os.path.dirname(__file__)
CHART = os.path.join(TESTS, "..", "otterscale-agent")
STACK = os.path.join(TESTS, "..", "prometheus-stack")
RELEASE = "otterscale-agent"
NS = "otterscale-system"
REQUIRED = ["--set", "agent.joinToken=t", "--set", "tenantOperator.harbor.robot.secret=s"]
PROM = "prometheus-stack-kube-prom-prometheus"


def docs(*extra):
    return render(RELEASE, CHART, NS, *REQUIRED, *extra)


def helm(*extra):
    return template(RELEASE, CHART, NS, *REQUIRED, *extra)


def check_env():
    data = find(docs(), "ConfigMap", "otterscale-agent-config")["data"]
    assert data["OTTERSCALE_AGENT_PROXY_PROMETHEUS_URL"] == f"https://{PROM}.monitoring.svc:9091", data
    assert data["OTTERSCALE_AGENT_PROXY_PROMETHEUS_CA_SECRET"] == f"monitoring/{PROM}-tls", data


def check_rbac():
    d = docs()
    rules = find(d, "ClusterRole", "otterscale-agent-metrics")["rules"]
    # kube-rbac-proxy maps a GET query to get and a POST one to create.
    assert {"apiGroups": ["monitoring.coreos.com"], "resources": ["prometheuses/api"],
            "resourceNames": [PROM], "verbs": ["get", "create"]} in rules, rules
    assert {"apiGroups": [""], "resources": ["secrets"],
            "resourceNames": [f"{PROM}-tls"], "verbs": ["get"]} in rules, rules
    crb = find(d, "ClusterRoleBinding", "otterscale-agent-metrics")
    assert crb["roleRef"]["name"] == "otterscale-agent-metrics"
    assert crb["subjects"] == [{"kind": "ServiceAccount", "name": RELEASE, "namespace": NS}], crb["subjects"]
    # The impersonation role stays as it was.
    assert find(d, "ClusterRole", RELEASE)["rules"] == [
        {"apiGroups": [""], "resources": ["users", "groups"], "verbs": ["impersonate"]}]


def check_defaults_match_prometheus_stack():
    stack = render("prometheus-stack", STACK, "monitoring")
    svc = find(stack, "Service", PROM)
    assert [p["port"] for p in svc["spec"]["ports"]] == [9091], svc["spec"]["ports"]
    find(stack, "Prometheus", PROM)
    certs = {d["spec"]["secretName"] for d in stack if d["kind"] == "Certificate"}
    assert f"{PROM}-tls" in certs, certs


def check_validate():
    # An empty URL would not turn the proxy off: the agent reads an empty
    # environment variable as unset and falls back to its built-in default.
    r = helm("--set", "metrics.prometheusURL=")
    assert r.returncode != 0 and "metrics.prometheusURL" in r.stderr, r.stderr[:200]
    r = helm("--set", "metrics.prometheusURL=prometheus:9090")
    assert r.returncode != 0 and "metrics.prometheusURL" in r.stderr, r.stderr[:200]
    r = helm("--set", "metrics.caSecret.name=")
    assert r.returncode != 0 and "metrics.caSecret" in r.stderr, r.stderr[:200]
    r = helm("--set", f"metrics.prometheusURL=http://{PROM}.monitoring.svc:9090", "--set", "metrics.caSecret.name=")
    assert r.returncode == 0, f"an http URL needs no CA: {r.stderr[:200]}"


if __name__ == "__main__":
    run([check_env, check_rbac, check_defaults_match_prometheus_stack, check_validate])
