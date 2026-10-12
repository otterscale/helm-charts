"""otterscale-agent ships otterscale:metrics-cluster-view: the one attribute the
OtterScale server checks for cluster-scope metrics (internal/core/access.go,
ClusterMetricsAccess), granted to nobody by default."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from render import find, render, run  # noqa: E402

CHART = os.path.join(os.path.dirname(__file__), "..", "otterscale-agent")
REQUIRED = ["--set", "agent.joinToken=t", "--set", "tenantOperator.harbor.robot.secret=s"]
NAME = "otterscale:metrics-cluster-view"
SERVER_RULE = [{
    "apiGroups": ["monitoring.coreos.com"],
    "resources": ["prometheuses/api"],
    "resourceNames": ["prometheus-stack-kube-prom-prometheus"],
    "verbs": ["get"],
}]


def docs(release="otterscale-agent", *extra):
    return render(release, CHART, "otterscale-system", *REQUIRED, *extra)


def check_rule_matches_server():
    role = find(docs(), "ClusterRole", NAME)
    assert role["rules"] == SERVER_RULE, role["rules"]


def check_rule_ignores_prometheus_name():
    # The server checks a fixed name, so the role must not follow the agent's
    # own metrics.prometheusName: not when it is overridden, and not as [""]
    # when an http prometheusURL leaves it empty.
    for extra in (
        ["--set", "metrics.prometheusName=custom-prometheus"],
        ["--set", "metrics.prometheusURL=http://prometheus.monitoring.svc:9090", "--set", "metrics.prometheusName="],
    ):
        role = find(docs("otterscale-agent", *extra), "ClusterRole", NAME)
        assert role["rules"] == SERVER_RULE, (extra, role["rules"])


def check_bound_to_nobody():
    for d in docs():
        if d["kind"] in ("ClusterRoleBinding", "RoleBinding"):
            assert d["roleRef"]["name"] != NAME, f"{d['kind']}/{d['metadata']['name']} binds {NAME}"


def check_name_is_fixed():
    # Operators bind it by this name on every cluster; it must not follow the release name.
    find(docs("other-release"), "ClusterRole", NAME)


if __name__ == "__main__":
    run([check_rule_matches_server, check_rule_ignores_prometheus_name, check_bound_to_nobody, check_name_is_fixed])
