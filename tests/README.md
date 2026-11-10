Render tests for the charts: each `test_*.py` runs `helm template` and asserts on the resulting objects.
Run them all with `make test`.
Requires helm and python3 with PyYAML.
