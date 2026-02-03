.PHONY: test lint

test:
	./test/test-commands.sh
	./test/test-update.sh

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x install.sh uninstall.sh src/terminal-guard.sh src/terminal-guard-update.sh test/test-commands.sh scripts/release.sh; \
	else \
		echo "shellcheck not installed; skipping lint"; \
	fi
