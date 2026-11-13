WOLFRAMSCRIPT ?= wolframscript

.DEFAULT_GOAL := help
.PHONY: help deps all check test test-gap sweep build runtime bundle verify verify-bundle check-release publish lint style style-fix hooks clean

help:
	@printf '  make %-14s %s\n' \
		deps 'fetch pinned PacletPage tools' \
		check 'metadata, lint, style, and source load' \
		test 'tests without GAP, or FILES="..."' \
		test-gap 'bridge and library tests with GAP' \
		sweep 'upstream GAP tests and function coverage' \
		build 'build docs and archive with PacletPage' \
		runtime 'build GAP for this system' \
		bundle 'platform archive with bundled GAP' \
		verify 'verify the PacletPage archive' \
		verify-bundle 'start GAP from the platform archive' \
		publish 'publish verified releases and documentation with PacletPage' \
		all 'check, test, and build' \
		lint 'CodeInspector and the style check on FILES="..."' \
		style 'check the code against the coding guides, or FILES="..."' \
		style-fix 'apply the mechanical style fixes, or FILES="..."; with no FILES, also update the rule table' \
		hooks 'enable local Git hooks'

deps:
	scripts/fetch-deps.sh

all build: deps

all check test-gap build verify verify-bundle check-release publish:
	$(WOLFRAMSCRIPT) -file scripts/project.wls $@

test lint style style-fix:
	$(WOLFRAMSCRIPT) -file scripts/project.wls $@ $(FILES)

sweep:
	$(WOLFRAMSCRIPT) -file scripts/project.wls sweep
	python3 scripts/coverage.py compare build/coverage

runtime:
	scripts/build-runtime.sh

bundle: build
	GAPLINK_RUNTIME="$(RUNTIME)" GAPLINK_SYSTEM_ID="$(SYSTEM_ID)" \
	$(WOLFRAMSCRIPT) -file scripts/project.wls bundle

hooks:
	git config core.hooksPath .githooks

clean:
	rm -rf -- "$(CURDIR)/build" "$(CURDIR)/GAPLink/build" "$(CURDIR)/GAPLink/Documentation" "$(CURDIR)/GAPLink/ResourceDefinition.nb"
