WOLFRAMSCRIPT ?= wolframscript

.DEFAULT_GOAL := help
.PHONY: help deps all check test test-gap sweep build runtime bundle verify verify-bundle publish lint hooks clean

help:
	@printf '  make %-14s %s\n' \
		deps 'fetch pinned PacletPage tools' \
		check 'metadata, lint, and source load' \
		test 'tests without GAP' \
		test-gap 'bridge and library tests with GAP' \
		sweep 'upstream GAP tests and function coverage' \
		build 'build docs and archive with PacletPage' \
		runtime 'build GAP for this system' \
		bundle 'platform archive with bundled GAP' \
		verify 'verify the PacletPage archive' \
		verify-bundle 'start GAP from the platform archive' \
		publish 'publish verified platform releases' \
		all 'check, test, and build' \
		hooks 'enable local Git hooks'

deps:
	scripts/fetch-deps.sh

all build: deps

all check test test-gap build verify verify-bundle publish:
	$(WOLFRAMSCRIPT) -file scripts/project.wls $@

sweep:
	$(WOLFRAMSCRIPT) -file scripts/project.wls sweep
	python3 scripts/coverage.py compare build/coverage

runtime:
	scripts/build-runtime.sh

bundle: build
	GAPLINK_RUNTIME="$(RUNTIME)" GAPLINK_SYSTEM_ID="$(SYSTEM_ID)" \
	$(WOLFRAMSCRIPT) -file scripts/project.wls bundle

lint:
	$(WOLFRAMSCRIPT) -file scripts/project.wls lint $(FILES)

hooks:
	git config core.hooksPath .githooks

clean:
	rm -rf -- "$(CURDIR)/build" "$(CURDIR)/GAPLink/build" "$(CURDIR)/GAPLink/Documentation" "$(CURDIR)/GAPLink/ResourceDefinition.nb"
