#!/usr/bin/env bash
set -euo pipefail

# Print a message to stdout.
install_log() {
  printf '%s\n' "$*"
}

# Print an error and exit.
install_die() {
  install_log "$*"
  exit 1
}

# Prompt before updating an existing install.
install_confirm_update() {
  local reply
  printf '%s' "terminal-guard already installed. Update? [y/N] " >/dev/tty
  IFS= read -r reply </dev/tty
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# Detect the user's login shell.
install_detect_shell() {
  if [ -n "${SHELL:-}" ]; then
    basename "$SHELL"
  else
    printf '%s\n' "bash"
  fi
}

# Ensure a directory exists.
install_ensure_dir() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
  fi
}

# Copy a file with basic validation.
install_copy_file() {
  local src="$1"
  local dest="$2"
  if [ ! -f "$src" ]; then
    install_log "Missing file: $src"
    return 1
  fi
  cp "$src" "$dest"
}

# Download a file using curl or wget.
install_download_file() {
  local url="$1"
  local dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    install_die "Neither curl nor wget is available to download $url"
  fi
}

# Ensure the source files exist; if not, download from GitHub.
install_prepare_sources() {
  local script_dir="$1"
  local repo="${TERMINAL_GUARD_REPO:-https://raw.githubusercontent.com/daveremy/terminal-guard/main}"
  local tmp_dir

  if [ -f "$script_dir/src/terminal-guard.sh" ] && [ -f "$script_dir/lib/confusables.txt" ]; then
    TG_SOURCE_DIR="$script_dir"
    return 0
  fi

  install_log "Running from remote installer; downloading latest files from $repo"
  tmp_dir="$(mktemp -d)"
  TG_SOURCE_DIR="$tmp_dir"
  TG_TEMP_DIR="$tmp_dir"
  trap 'rm -rf "$TG_TEMP_DIR"' EXIT

  install_download_file "$repo/src/terminal-guard.sh" "$tmp_dir/src-terminal-guard.sh"
  install_download_file "$repo/src/terminal-guard.zsh" "$tmp_dir/src-terminal-guard.zsh"
  install_download_file "$repo/src/terminal-guard.py" "$tmp_dir/src-terminal-guard.py"
  install_download_file "$repo/src/terminal-guard-update.sh" "$tmp_dir/src-terminal-guard-update.sh"
  install_download_file "$repo/lib/confusables.txt" "$tmp_dir/lib-confusables.txt"
  install_download_file "$repo/VERSION" "$tmp_dir/version"
}

# Add a sourcing block to a shell rc file.
install_add_rc_block() {
  local rc_file="$1"
  local source_line="$2"
  local begin_marker="# >>> terminal-guard >>>"
  local end_marker="# <<< terminal-guard <<<"

  if [ ! -f "$rc_file" ]; then
    touch "$rc_file"
  fi

  if grep -Fq "$begin_marker" "$rc_file"; then
    install_log "terminal-guard already referenced in $rc_file"
    return 0
  fi

  {
    printf '\n%s\n' "$begin_marker"
    printf '%s\n' "$source_line"
    printf '%s\n' "$end_marker"
  } >>"$rc_file"
}

# Install terminal-guard files and hooks.
install_main() {
  local script_dir install_dir shell_name rc_file
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  install_dir="${HOME}/.local/bin"

  install_log "Installing terminal-guard into $install_dir"
  install_ensure_dir "$install_dir"

  install_prepare_sources "$script_dir"

  if [ -f "$install_dir/terminal-guard.sh" ]; then
    if ! install_confirm_update; then
      install_log "Install canceled."
      return 0
    fi
  fi

  if [ "$TG_SOURCE_DIR" = "$script_dir" ]; then
    install_copy_file "$TG_SOURCE_DIR/src/terminal-guard.sh" "$install_dir/terminal-guard.sh"
    install_copy_file "$TG_SOURCE_DIR/src/terminal-guard.zsh" "$install_dir/terminal-guard.zsh"
    install_copy_file "$TG_SOURCE_DIR/src/terminal-guard.py" "$install_dir/terminal-guard.py"
    install_copy_file "$TG_SOURCE_DIR/src/terminal-guard-update.sh" "$install_dir/terminal-guard-update"
    install_copy_file "$TG_SOURCE_DIR/lib/confusables.txt" "$install_dir/terminal-guard.confusables"
    if [ -f "$TG_SOURCE_DIR/VERSION" ]; then
      install_copy_file "$TG_SOURCE_DIR/VERSION" "$install_dir/terminal-guard.version"
    fi
  else
    install_copy_file "$TG_SOURCE_DIR/src-terminal-guard.sh" "$install_dir/terminal-guard.sh"
    install_copy_file "$TG_SOURCE_DIR/src-terminal-guard.zsh" "$install_dir/terminal-guard.zsh"
    install_copy_file "$TG_SOURCE_DIR/src-terminal-guard.py" "$install_dir/terminal-guard.py"
    install_copy_file "$TG_SOURCE_DIR/src-terminal-guard-update.sh" "$install_dir/terminal-guard-update"
    install_copy_file "$TG_SOURCE_DIR/lib-confusables.txt" "$install_dir/terminal-guard.confusables"
    install_copy_file "$TG_SOURCE_DIR/version" "$install_dir/terminal-guard.version"
  fi

  chmod 644 "$install_dir/terminal-guard.sh"
  chmod 644 "$install_dir/terminal-guard.zsh"
  chmod 644 "$install_dir/terminal-guard.confusables"
  chmod 755 "$install_dir/terminal-guard-update"
  chmod 644 "$install_dir/terminal-guard.version"
  chmod 755 "$install_dir/terminal-guard.py"

  shell_name="$(install_detect_shell)"
  case "$shell_name" in
    zsh)
      rc_file="${HOME}/.zshrc"
      install_add_rc_block "$rc_file" "[ -f \"$install_dir/terminal-guard.zsh\" ] && source \"$install_dir/terminal-guard.zsh\""
      ;;
    bash)
      rc_file="${HOME}/.bashrc"
      install_add_rc_block "$rc_file" "[ -f \"$install_dir/terminal-guard.sh\" ] && source \"$install_dir/terminal-guard.sh\""
      ;;
    fish)
      install_log "fish detected. Manual install needed: source terminal-guard.sh in your config.fish"
      ;;
    *)
      install_log "Unknown shell ($shell_name). Add a source line manually."
      ;;
  esac

  install_log "Install complete."
  install_log "Load now: source ~/.zshrc  # or source ~/.bashrc"
  install_log "Or restart: exec $SHELL -l"
  install_log "Example bypass: TERMINAL_GUARD=0 curl https://example.com | bash"
  install_log "Update later: terminal-guard-update"
}

# This installer intentionally avoids curl|bash; use git clone instead.
install_main
