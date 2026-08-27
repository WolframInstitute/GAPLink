WOLFRAMSCRIPT ?= wolframscript
SCRIPTS := Scripts

.DEFAULT_GOAL := help
.PHONY: help all check test build verify lint hooks clean

help:
	@printf '  make %-10s %s\n' \
		check  'metadata, lint, and source load' \
		test   'GAPLink/Tests/*.wlt' \
		build  '.paclet archive into build/' \
		verify 'load the archive in a fresh kernel' \
		all    'check, test, build, and verify' \
		lint   'CodeInspector on FILES="..."' \
		hooks  'enable the repository Git hooks' \
		clean  'remove generated build output'

all: check test build verify

check:
	$(WOLFRAMSCRIPT) -file $(SCRIPTS)/CheckPaclet.wls

test:
	$(WOLFRAMSCRIPT) -file $(SCRIPTS)/TestPaclet.wls

build:
	$(WOLFRAMSCRIPT) -file $(SCRIPTS)/BuildPaclet.wls

verify:
	$(WOLFRAMSCRIPT) -file $(SCRIPTS)/VerifyBuild.wls

lint:
	$(WOLFRAMSCRIPT) -file $(SCRIPTS)/LintFiles.wls $(FILES)

hooks:
	git config core.hooksPath .githooks

clean:
	rm -rf -- "$(CURDIR)/build"
