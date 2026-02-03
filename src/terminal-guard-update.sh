#!/usr/bin/env bash
set -euo pipefail

# Update terminal-guard by re-running the installer from GitHub.
terminal_guard_update_main() {
  local repo local_version remote_version cache_bust
  repo="${TERMINAL_GUARD_REPO:-https://raw.githubusercontent.com/daveremy/terminal-guard/main}"

  local_version="$(terminal_guard_update_local_version)"
  remote_version="$(terminal_guard_update_remote_version "$repo")"

  if [ -n "$local_version" ] && [ -n "$remote_version" ] && [ "$local_version" = "$remote_version" ]; then
    printf '%s\n' "terminal-guard is up to date ($local_version)."
    return 0
  fi

  if [ -n "$remote_version" ] && [ -n "$local_version" ]; then
    printf '%s\n' "Updating terminal-guard ($local_version -> $remote_version)."
  fi

  cache_bust="t=$(date +%s)"
  export TERMINAL_GUARD_INSTALL_MODE="update"
  export TERMINAL_GUARD_CACHE_BUST="$cache_bust"
  export TERMINAL_GUARD=0

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$repo/install.sh?$cache_bust" | bash
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO- "$repo/install.sh?$cache_bust" | bash
    return 0
  fi

  printf '%s\n' "terminal-guard-update: curl or wget is required" >&2
  return 1
}

# Read the locally installed version, if available.
terminal_guard_update_local_version() {
  local version_file
  version_file="${HOME}/.local/bin/terminal-guard.version"
  if [ -f "$version_file" ]; then
    tr -d ' \n' <"$version_file"
  fi
}

# Fetch the remote version from GitHub.
terminal_guard_update_remote_version() {
  local repo="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time 3 "$repo/VERSION" 2>/dev/null | tr -d ' \n'
    return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO- --timeout=3 "$repo/VERSION" 2>/dev/null | tr -d ' \n'
    return 0
  fi
  return 1
}

terminal_guard_update_main
