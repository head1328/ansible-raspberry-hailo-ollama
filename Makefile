SHELL = /bin/bash
.SHELLFLAGS = -e -o pipefail -c
ANSIBLE_ARGS ?= $(ANSIBLE_OPTIONS)

ifdef ANSIBLE_TAGS
ANSIBLE_ARGS := $(ANSIBLE_ARGS) --tags='$(ANSIBLE_TAGS)'
endif

export PY_COLORS=1
export ANSIBLE_FORCE_COLOR=1

.PHONY: test
test:
	molecule test

.PHONY: test-all
test-all:
	molecule test --all

.PHONY: converge
converge:
	molecule converge

.PHONY: verify
verify:
	molecule verify

.PHONY: destroy
destroy:
	molecule destroy

.PHONY: login
login:
	molecule login

.PHONY: test-simulate
test-simulate:
	molecule test --scenario-name simulate

.PHONY: lint
lint:
	ansible-lint --force-color .
