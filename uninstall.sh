#!/usr/bin/env bash
set -euo pipefail

# Print a message to stdout.
uninstall_log() {
  printf '%s\n' "$*"
}

# Prompt for confirmation before uninstalling.
uninstall_confirm() {
  local reply
  printf '%s' "Remove terminal-guard from this machine? [y/N] " >/dev/tty
  IFS= read -r reply </dev/tty
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# Remove the terminal-guard block from a shell rc file.
uninstall_remove_rc_block() {
  local rc_file="$1"
  local begin_marker="# >>> terminal-guard >>>"
  local end_marker="# <<< terminal-guard <<<"
  local tmp_file

  [ -f "$rc_file" ] || return 0

  tmp_file="${rc_file}.tg.tmp"
  awk -v begin="$begin_marker" -v end="$end_marker" '
    $0 ~ begin {inblock=1; next}
    $0 ~ end {inblock=0; next}
    !inblock {print}
  ' "$rc_file" >"$tmp_file"
  mv "$tmp_file" "$rc_file"
}

# Remove installed terminal-guard files.
uninstall_remove_files() {
  local install_dir="$1"
  rm -f "$install_dir/terminal-guard.sh"
  rm -f "$install_dir/terminal-guard.zsh"
  rm -f "$install_dir/terminal-guard.py"
  rm -f "$install_dir/terminal-guard.confusables"
}

# Uninstall terminal-guard.
uninstall_main() {
  local install_dir
  install_dir="${HOME}/.local/bin"

  if ! uninstall_confirm; then
    uninstall_log "Uninstall canceled."
    return 0
  fi

  uninstall_remove_rc_block "${HOME}/.bashrc"
  uninstall_remove_rc_block "${HOME}/.zshrc"
  uninstall_remove_files "$install_dir"

  uninstall_log "terminal-guard removed. Restart your shell to complete uninstall."
}

uninstall_main
