.DEFAULT_GOAL := help

WOW_ADDONS ?= /Applications/World of Warcraft/_forever_/Interface/AddOns
ADDON      := ReagentTracker
VERSION    := $(shell sed -n 's/^\#\# Version: *//p' $(ADDON)/$(ADDON).toc)

.PHONY: help test lint check verify install uninstall package

help: ## List available targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "%-10s %s\n", $$1, $$2}'

test: ## Run the test suite (LuaJIT)
	luajit tests/run.lua

lint: ## Syntax-check every addon file as Lua 5.1
	@for f in $(ADDON)/*.lua; do luajit -bl "$$f" > /dev/null || exit 1; done; echo "lint: ok"

check: lint test ## The gate — lint + tests

verify: check ## Alias for check

install: ## Link the addon into the local WoW Forever AddOns folder
	ln -sfn "$(CURDIR)/$(ADDON)" "$(WOW_ADDONS)/$(ADDON)"

uninstall: ## Remove that link (only if it is a symlink)
	@if [ -L "$(WOW_ADDONS)/$(ADDON)" ]; then rm "$(WOW_ADDONS)/$(ADDON)" && echo removed; else echo "not a symlink, left alone"; fi

package: check ## Build release/ReagentTracker-<version>.zip (the installable addon)
	@mkdir -p release
	@rm -f "release/$(ADDON)-$(VERSION).zip"
	zip -qrX "release/$(ADDON)-$(VERSION).zip" $(ADDON) -x '*.DS_Store'
	@unzip -l "release/$(ADDON)-$(VERSION).zip"
