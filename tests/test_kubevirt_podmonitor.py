"""kubevirt's PodMonitor keeps the VMI's own namespace label (honorLabels), so a
VM's metrics land in the VM's namespace — what namespace-scoped metrics
enforce on. Safe only because it selects pods in the kubevirt namespace, where
tenants cannot create pods."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from render import find, render, run  # noqa: E402

CHART = os.path.join(os.path.dirname(__file__), "..", "kubevirt")


def monitor():
    return find(render("kubevirt", CHART, "kubevirt"), "PodMonitor", "kubevirt")


def check_honor_labels():
    endpoints = monitor()["spec"]["podMetricsEndpoints"]
    assert endpoints and all(e.get("honorLabels") is True for e in endpoints), endpoints


def check_only_kubevirt_namespace():
    spec = monitor()["spec"]
    assert spec["namespaceSelector"] == {"matchNames": ["kubevirt"]}, spec["namespaceSelector"]
    assert spec["selector"]["matchLabels"]["prometheus.kubevirt.io"] == "true", spec["selector"]


if __name__ == "__main__":
    run([check_honor_labels, check_only_kubevirt_namespace])
