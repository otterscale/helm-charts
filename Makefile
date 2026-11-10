HELM ?= helm

ROOT   := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
CHARTS := $(patsubst $(ROOT)/%/Chart.yaml,%,$(wildcard $(ROOT)/*/Chart.yaml))

# helm shares a repository cache, so keep chart updates serialized.
.NOTPARALLEL:

.PHONY: all deps repo-update list clean test help $(CHARTS)

all: deps

## deps: run `helm dependency update` for all charts
deps: $(CHARTS)

# refresh the repository indexes once, then let each chart resolve from cache
repo-update:
	@echo "==> helm repo update"
	@$(HELM) repo update

$(CHARTS): repo-update
	@echo "==> $@"
	$(HELM) dependency update --skip-refresh $(ROOT)/$@

## list: print the charts discovered in this folder
list:
	@printf '%s\n' $(CHARTS)

## clean: drop the vendored charts/ directories
clean:
	@rm -rf $(addprefix $(ROOT)/,$(addsuffix /charts,$(CHARTS)))
	@echo "removed vendored charts/ directories"

## test: render tests (needs helm and python3 with PyYAML)
test:
	@for t in tests/test_*.py; do python3 $$t || exit 1; done

## help: show this message
help:
	@echo "targets: all deps list clean test help"
	@echo "charts:  $(CHARTS)"
