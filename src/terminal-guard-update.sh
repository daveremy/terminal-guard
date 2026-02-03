#!/usr/bin/env bash
set -euo pipefail

# Update terminal-guard by re-running the installer from GitHub.
terminal_guard_update_main() {
  local repo
  repo="${TERMINAL_GUARD_REPO:-https://raw.githubusercontent.com/daveremy/terminal-guard/main}"

  export TERMINAL_GUARD_INSTALL_MODE="update"
  export TERMINAL_GUARD=0

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$repo/install.sh" | bash
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO- "$repo/install.sh" | bash
    return 0
  fi

  printf '%s\n' "terminal-guard-update: curl or wget is required" >&2
  return 1
}

terminal_guard_update_main
