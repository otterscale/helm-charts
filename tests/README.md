Render tests for the charts: each `test_*.py` runs `helm template` and asserts on the resulting objects.
Run them all with `make test`.
Requires helm and python3 with PyYAML.
prometheus-stack's subchart is not committed: `make test` runs `helm dependency build` for it when it is missing, which needs `helm repo add prometheus-community https://prometheus-community.github.io/helm-charts`.
