"""Shared helpers for chart render tests: `helm template`, then look objects up."""
import subprocess
import sys

import yaml


def render(release, chart, namespace, *extra):
    r = subprocess.run(
        ["helm", "template", release, chart, "-n", namespace, *extra],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        sys.exit(f"helm template {chart} failed:\n{r.stderr}")
    return [d for d in yaml.safe_load_all(r.stdout) if d]


def find(docs, kind, name):
    hits = [d for d in docs if d["kind"] == kind and d["metadata"]["name"] == name]
    assert len(hits) == 1, f"want exactly one {kind}/{name}, got {len(hits)}"
    return hits[0]


def run(checks):
    failed = 0
    for check in checks:
        try:
            check()
            print(f"PASS  {check.__name__}")
        except (AssertionError, KeyError, TypeError) as e:
            failed += 1
            print(f"FAIL  {check.__name__}: {e!r}")
    sys.exit(1 if failed else 0)
