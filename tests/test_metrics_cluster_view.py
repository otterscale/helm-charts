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


def docs(release="otterscale-agent"):
    return render(release, CHART, "otterscale-system", *REQUIRED)


def check_rule_matches_server():
    role = find(docs(), "ClusterRole", NAME)
    assert role["rules"] == [{
        "apiGroups": ["monitoring.coreos.com"],
        "resources": ["prometheuses/api"],
        "resourceNames": ["prometheus-stack-kube-prom-prometheus"],
        "verbs": ["get"],
    }], role["rules"]


def check_bound_to_nobody():
    for d in docs():
        if d["kind"] in ("ClusterRoleBinding", "RoleBinding"):
            assert d["roleRef"]["name"] != NAME, f"{d['kind']}/{d['metadata']['name']} binds {NAME}"


def check_name_is_fixed():
    # Operators bind it by this name on every cluster; it must not follow the release name.
    find(docs("other-release"), "ClusterRole", NAME)


if __name__ == "__main__":
    run([check_rule_matches_server, check_bound_to_nobody, check_name_is_fixed])
