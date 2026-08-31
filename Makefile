WOLFRAMSCRIPT ?= wolframscript

.DEFAULT_GOAL := help
.PHONY: help all check test test-gap build verify lint hooks clean

help:
	@printf '  make %-10s %s\n' \
		check  'metadata, lint, and source load' \
		test   'GAP-free tests' \
		test-gap 'startup test with installed GAP' \
		build  '.paclet archive into build/' \
		verify 'load the archive in a fresh kernel' \
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

verify:
	$(WOLFRAMSCRIPT) -file scripts/verify.wls

lint:
	$(WOLFRAMSCRIPT) -file scripts/lint.wls $(FILES)

hooks:
	git config core.hooksPath .githooks

clean:
	rm -rf -- "$(CURDIR)/build"
