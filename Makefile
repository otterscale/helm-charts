HELM ?= helm

ROOT   := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
CHARTS := $(patsubst $(ROOT)/%/Chart.yaml,%,$(wildcard $(ROOT)/*/Chart.yaml))

# helm shares a repository cache, so keep chart updates serialized.
.NOTPARALLEL:

.PHONY: all deps list clean help $(CHARTS)

all: deps

## deps: run `helm dependency update` for all charts
deps: $(CHARTS)

$(CHARTS):
	@echo "==> $@"
	$(HELM) dependency update $(ROOT)/$@

## list: print the charts discovered in this folder
list:
	@printf '%s\n' $(CHARTS)

## clean: drop the vendored charts/ directories
clean:
	@rm -rf $(addprefix $(ROOT)/,$(addsuffix /charts,$(CHARTS)))
	@echo "removed vendored charts/ directories"

## help: show this message
help:
	@echo "targets: all deps list clean help"
	@echo "charts:  $(CHARTS)"
