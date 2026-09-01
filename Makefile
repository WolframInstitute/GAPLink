WOLFRAMSCRIPT ?= wolframscript

.DEFAULT_GOAL := help
.PHONY: help all check test test-gap build runtime bundle verify verify-bundle publish lint hooks clean

help:
	@printf '  make %-14s %s\n' \
		check  'metadata, lint, and source load' \
		test   'GAP-free tests' \
		test-gap 'startup test with installed GAP' \
		build  '.paclet archive into build/' \
		runtime 'build GAP for this system' \
		bundle 'platform paclet from the built runtime' \
		verify 'load the archive in a fresh kernel' \
		verify-bundle 'start GAP from the platform paclet' \
		publish 'upload platform paclets to Wolfram Cloud' \
		all    'GAP-free full check in one kernel' \
		lint   'CodeInspector on FILES="..."' \
		hooks  'enable the repository Git hooks' \
		clean  'remove generated build output'

all:
	$(WOLFRAMSCRIPT) -file scripts/all.wls

check:
	$(WOLFRAMSCRIPT) -file scripts/check.wls

test:
	$(WOLFRAMSCRIPT) -file scripts/test.wls

test-gap:
	$(WOLFRAMSCRIPT) -file scripts/test-gap.wls

build:
	$(WOLFRAMSCRIPT) -file scripts/build.wls

runtime:
	scripts/build-runtime.sh

bundle:
	GAPLINK_RUNTIME="$(RUNTIME)" \
	GAPLINK_SYSTEM_ID="$(SYSTEM_ID)" \
	$(WOLFRAMSCRIPT) -file scripts/bundle.wls

verify:
	$(WOLFRAMSCRIPT) -file scripts/verify.wls

verify-bundle:
	$(WOLFRAMSCRIPT) -file scripts/verify-bundle.wls

publish:
	$(WOLFRAMSCRIPT) -file scripts/publish.wls

lint:
	$(WOLFRAMSCRIPT) -file scripts/lint.wls $(FILES)

hooks:
	git config core.hooksPath .githooks

clean:
	rm -rf -- "$(CURDIR)/build"
