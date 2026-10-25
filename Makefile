SHELL_FILES := bin/webapp-install bin/webapp-remove install.sh uninstall.sh .quality-gate.sh $(wildcard scripts/*.sh) test/helper.bash
BATS_FILES := $(wildcard test/*.bats)
PREFIX ?= $(HOME)/.local

.PHONY: all check lint fmt test install uninstall

all: check

check: lint test

lint:
	shellcheck $(SHELL_FILES)
	shellcheck -x -P test $(BATS_FILES)
	shfmt -d -i 2 -ci $(SHELL_FILES) $(BATS_FILES)

fmt:
	shfmt -w -i 2 -ci $(SHELL_FILES) $(BATS_FILES)

test:
	bats test/

install:
	PREFIX="$(PREFIX)" ./install.sh

uninstall:
	PREFIX="$(PREFIX)" ./uninstall.sh
