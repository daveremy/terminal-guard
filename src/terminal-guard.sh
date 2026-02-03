#!/usr/bin/env bash
# terminal-guard.sh - minimal, auditable terminal guard for bash/zsh

# Global state for warnings.
TG_WARNINGS=""
TG_WARN_COUNT=0
TG_SEEN_HOSTS=""
TERMINAL_GUARD_VERSION="0.1.9"

# Determine the directory of this script for loading data files.
terminal_guard_script_dir() {
  local src=""
  if [ -n "${BASH_SOURCE[0]:-}" ]; then
    src="${BASH_SOURCE[0]}"
  elif [ -n "${ZSH_VERSION:-}" ]; then
    # shellcheck disable=SC2296
    src="${(%):-%N}"
  else
    src="$0"
  fi
  if [ -n "$src" ]; then
    (cd "$(dirname "$src")" && pwd)
  else
    printf '%s\n' "."
  fi
}

# Return the directory for storing state files.
terminal_guard_state_dir() {
  local base
  base="${XDG_STATE_HOME:-$HOME/.local/state}"
  if [ ! -d "$base" ]; then
    base="${XDG_CACHE_HOME:-$HOME/.cache}"
  fi
  printf '%s/terminal-guard\n' "$base"
}

# Return 0 if the shell is interactive.
terminal_guard_is_interactive() {
  case "$-" in
    *i*) return 0 ;;
    *) return 1 ;;
  esac
}

# Return the local version string.
terminal_guard_local_version() {
  if [ -n "${TG_VERSION_FILE:-}" ] && [ -f "$TG_VERSION_FILE" ]; then
    tr -d ' \n' <"$TG_VERSION_FILE"
    return 0
  fi
  printf '%s\n' "$TERMINAL_GUARD_VERSION"
}

# Fetch the remote version string if possible.
terminal_guard_fetch_remote_version() {
  local repo
  repo="${TERMINAL_GUARD_REPO:-https://raw.githubusercontent.com/daveremy/terminal-guard/main}"

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

# Return 0 if an update check is due.
terminal_guard_update_check_due() {
  local state_file="$1"
  local now last interval
  interval="${TERMINAL_GUARD_UPDATE_INTERVAL:-86400}"
  now="$(date +%s)"
  last=0
  if [ -f "$state_file" ]; then
    last="$(cat "$state_file" 2>/dev/null || printf '0')"
  fi
  if [ $((now - last)) -lt "$interval" ]; then
    return 1
  fi
  printf '%s' "$now" >"$state_file"
  return 0
}

# Check for available updates and notify once per interval.
terminal_guard_check_updates() {
  local state_dir state_file remote local_version yellow reset update_cmd
  if [ "${TERMINAL_GUARD_UPDATE_CHECK:-1}" = "0" ]; then
    return 0
  fi
  if [ "${TERMINAL_GUARD_TEST:-0}" = "1" ]; then
    return 0
  fi

  state_dir="$(terminal_guard_state_dir)"
  mkdir -p "$state_dir" 2>/dev/null || return 0
  state_file="$state_dir/last-update-check"

  if ! terminal_guard_update_check_due "$state_file"; then
    return 0
  fi

  remote="$(terminal_guard_fetch_remote_version)"
  local_version="$(terminal_guard_local_version)"
  if [ -n "$remote" ] && [ -n "$local_version" ] && [ "$remote" != "$local_version" ]; then
    update_cmd="terminal-guard-update"
    if [ -n "${TG_DIR:-}" ] && [ -x "${TG_DIR}/terminal-guard-update" ]; then
      update_cmd="${TG_DIR}/terminal-guard-update"
    fi
    yellow="\033[33m"
    reset="\033[0m"
    printf '%b\n' "${yellow}terminal-guard: update available ($local_version -> $remote). Run: $update_cmd${reset}" >/dev/tty
  fi
}

# Return 0 if the command should bypass terminal-guard.
terminal_guard_should_bypass() {
  local cmd="$1"
  if [ "${TERMINAL_GUARD:-1}" = "0" ]; then
    return 0
  fi
  case "$cmd" in
    TERMINAL_GUARD=0\ *|TERMINAL_GUARD=0) return 0 ;;
  esac
  return 1
}

# Reset warning buffer for a new scan.
terminal_guard_reset_warnings() {
  TG_WARNINGS=""
  TG_WARN_COUNT=0
  TG_SEEN_HOSTS=""
}

# Append a warning to the buffer.
terminal_guard_add_warning() {
  local severity="$1"
  shift
  local message="$*"
  TG_WARNINGS="${TG_WARNINGS}${severity}|${message}
"
  TG_WARN_COUNT=$((TG_WARN_COUNT + 1))
}

# Print warnings to the terminal with color.
terminal_guard_print_warnings() {
  local line severity message color
  local red="\033[31m"
  local yellow="\033[33m"
  local reset="\033[0m"

  printf '%b\n' "${yellow}terminal-guard: detected suspicious patterns:${reset}" >/dev/tty
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    severity="${line%%|*}"
    message="${line#*|}"
    if [ "$severity" = "critical" ]; then
      color="$red"
    else
      color="$yellow"
    fi
    printf '%b%s%b\n' "$color" "$message" "$reset" >/dev/tty
  done <<EOW
$TG_WARNINGS
EOW
}

# Prompt the user for confirmation.
terminal_guard_prompt() {
  local reply
  printf '%s' "Proceed? [y/N] " >/dev/tty
  IFS= read -r reply </dev/tty
  case "$reply" in
    y|Y|yes|YES)
      printf '%s' "Really proceed? [y/N] " >/dev/tty
      IFS= read -r reply </dev/tty
      case "$reply" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

# Return 0 if string contains non-ASCII characters.
terminal_guard_has_non_ascii() {
  local text="$1"
  printf '%s' "$text" | LC_ALL=C grep -q '[^ -~]'
}

# Return 0 if the host has already been checked.
terminal_guard_seen_host() {
  local host="$1"
  if [ -z "$host" ]; then
    return 1
  fi
  printf '%s\n' "$TG_SEEN_HOSTS" | grep -Fxq "$host"
}

# Track a host as already checked.
terminal_guard_mark_seen_host() {
  local host="$1"
  if [ -z "$host" ]; then
    return 0
  fi
  TG_SEEN_HOSTS="${TG_SEEN_HOSTS}${host}
"
}

# Return a human-readable list of non-ASCII chars with codepoints (optional).
terminal_guard_non_ascii_detail() {
  local text="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$text" <<'PY'
import sys
s = sys.argv[1]
seen = []
for ch in s:
    if ord(ch) > 127 and ch not in seen:
        seen.append(ch)
if seen:
    parts = [f"'{ch}'(U+{ord(ch):04X})" for ch in seen]
    print("chars: " + " ".join(parts))
PY
  fi
}

# Warn on punycode (IDN) labels in hostnames.
terminal_guard_check_punycode() {
  local host="$1"
  local origin="$2"
  if printf '%s' "$host" | grep -Eq '(^|\\.)xn--'; then
    terminal_guard_add_warning "caution" "[punycode] $origin hostname: \"$host\" (IDN punycode)"
  fi
}

# Print the confusables data to stdout.
terminal_guard_confusables_source() {
  if [ -n "${TG_CONFUSABLES:-}" ] && [ -f "$TG_CONFUSABLES" ]; then
    cat "$TG_CONFUSABLES"
  else
    printf '%s\n' "# missing confusables file"
  fi
}

# Check a hostname for confusable characters.
terminal_guard_check_confusables() {
  local host="$1"
  local origin="$2"
  local char code latin name
  while IFS=$'\t' read -r char code latin name; do
    [ -z "$char" ] && continue
    case "$char" in
      \#*) continue ;;
    esac
    if printf '%s' "$host" | grep -Fq "$char"; then
      terminal_guard_add_warning "critical" "[homoglyph] $origin contains '$char' ($code) mimicking '$latin' ($name)"
    fi
  done < <(terminal_guard_confusables_source)
}

# Check for non-ASCII characters in a hostname.
terminal_guard_check_host_non_ascii() {
  local host="$1"
  local origin="$2"
  if [ -n "$host" ] && terminal_guard_has_non_ascii "$host"; then
    local detail
    detail="$(terminal_guard_non_ascii_detail "$host")"
    if [ -n "$detail" ]; then
      terminal_guard_add_warning "critical" "[non-ascii-host] $origin hostname: \"$host\" ($detail)"
    else
      terminal_guard_add_warning "critical" "[non-ascii-host] $origin hostname: \"$host\""
    fi
  fi
}

# Extract the host portion from a URL.
terminal_guard_host_from_url() {
  local url="$1"
  local host="${url#*://}"
  host="${host%%/*}"
  host="${host%%\?*}"
  host="${host%%\#*}"
  host="${host##*@}"
  host="${host%%:*}"
  printf '%s\n' "$host"
}

# Extract explicit http(s) URLs from a command line.
terminal_guard_extract_urls() {
  local cmd="$1"
  printf '%s\n' "$cmd" | grep -Eo 'https?://[^[:space:]"'"'"'<>]+' || true
}

# Return 0 if the command looks like a network fetch or clone.
terminal_guard_is_network_command() {
  local cmd="$1"
  printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])(curl|wget|git[[:space:]]+clone)([[:space:]]|$)'
}

# Extract domain-like tokens from a command line.
terminal_guard_extract_domain_tokens() {
  local cmd="$1"
  printf '%s\n' "$cmd" \
    | tr ' ' '\n' \
    | sed -E 's/^["'"'"']//; s/["'"'"',;]+$//; s/^https?:\/\///; s/^ssh:\/\///' \
    | grep -E '([A-Za-z0-9-]+\.)+[A-Za-z]{2,}' || true
}

# Normalize a token into a hostname.
terminal_guard_host_from_token() {
  local token="$1"
  local host="$token"
  host="${host##*@}"
  host="${host%%/*}"
  host="${host%%:*}"
  printf '%s\n' "$host"
}

# Check all URLs and domain tokens for host issues.
terminal_guard_check_urls() {
  local cmd="$1"
  local url host token

  while IFS= read -r url; do
    [ -z "$url" ] && continue
    host="$(terminal_guard_host_from_url "$url")"
    if ! terminal_guard_seen_host "$host"; then
      terminal_guard_check_host_non_ascii "$host" "$url"
      terminal_guard_check_confusables "$host" "$url"
      terminal_guard_check_punycode "$host" "$url"
      terminal_guard_mark_seen_host "$host"
    fi
  done <<<"$(terminal_guard_extract_urls "$cmd")"

  if terminal_guard_is_network_command "$cmd"; then
    while IFS= read -r token; do
      [ -z "$token" ] && continue
      host="$(terminal_guard_host_from_token "$token")"
      if terminal_guard_seen_host "$host"; then
        continue
      fi
      terminal_guard_check_host_non_ascii "$host" "$token"
      terminal_guard_check_confusables "$host" "$token"
      terminal_guard_check_punycode "$host" "$token"
      terminal_guard_mark_seen_host "$host"
    done <<<"$(terminal_guard_extract_domain_tokens "$cmd")"
  fi
}

# Detect risky pipe-to-shell patterns.
terminal_guard_check_pipe_to_shell() {
  local cmd="$1"
  if printf '%s' "$cmd" | grep -Eq '\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh|zsh|fish|python|perl)([[:space:]]|$)'; then
    terminal_guard_add_warning "critical" "[pipe-to-shell] download and inspect first (e.g., curl | bash)"
  fi
  if printf '%s' "$cmd" | grep -Eq '(bash|sh|zsh|python|perl)[[:space:]]+<\([[:space:]]*(curl|wget)'; then
    terminal_guard_add_warning "critical" "[pipe-to-shell] process substitution from curl/wget"
  fi
}

# Detect ANSI escape sequences in the command.
terminal_guard_check_ansi() {
  local cmd="$1"
  if printf '%s' "$cmd" | LC_ALL=C grep -q $'\x1b'; then
    terminal_guard_add_warning "critical" "[ansi-escape] escape sequence detected (can hide text)"
  fi
}

# Detect bidirectional control characters in the command.
terminal_guard_check_bidi() {
  local cmd="$1"
  local code name char
  while IFS='|' read -r code name; do
    [ -z "$code" ] && continue
    char="$(printf '%b' "\\u$code")"
    if printf '%s' "$cmd" | grep -Fq "$char"; then
      terminal_guard_add_warning "critical" "[bidi] U+$code $name (display order can be spoofed)"
    fi
  done <<'EOBIDI'
202A|LEFT-TO-RIGHT EMBEDDING
202B|RIGHT-TO-LEFT EMBEDDING
202D|LEFT-TO-RIGHT OVERRIDE
202E|RIGHT-TO-LEFT OVERRIDE
2066|LEFT-TO-RIGHT ISOLATE
2067|RIGHT-TO-LEFT ISOLATE
2068|FIRST STRONG ISOLATE
2069|POP DIRECTIONAL ISOLATE
200E|LEFT-TO-RIGHT MARK
200F|RIGHT-TO-LEFT MARK
EOBIDI
}

# Return 0 if command is a safe source of a known shell rc file.
terminal_guard_is_safe_source() {
  local cmd="$1"
  # shellcheck disable=SC2016
  printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])(source|\.)[[:space:]]+("?\$HOME"?/\.bashrc|"?\$HOME"?/\.zshrc|"?\$HOME"?/\.profile|"?\$HOME"?/\.bash_profile|~/.bashrc|~/.zshrc|~/.profile|~/.bash_profile)([[:space:]]|$)'
}

# Detect operations targeting sensitive dotfiles.
terminal_guard_check_dotfiles() {
  local cmd="$1"
  local sensitive=0
  local writing=0

  # shellcheck disable=SC2016
  if printf '%s' "$cmd" | grep -Eq '(~|\$HOME)/\.ssh/|(~|\$HOME)/\.ssh$|\.ssh/|\.ssh$|(~|\$HOME)/\.bashrc|(~|\$HOME)/\.zshrc|(~|\$HOME)/\.profile|(~|\$HOME)/\.bash_profile|(~|\$HOME)/\.gitconfig'; then
    sensitive=1
  fi

  if printf '%s' "$cmd" | grep -Eq '>>|[^0-9]>[^>]|\|[[:space:]]*tee([[:space:]]|$)|sed[[:space:]]+-i'; then
    writing=1
  fi

  if [ "$sensitive" -eq 1 ] && [ "$writing" -eq 1 ]; then
    terminal_guard_add_warning "critical" "[dotfile-write] write to sensitive path (~/.ssh or shell rc files)"
  elif [ "$sensitive" -eq 1 ]; then
    if terminal_guard_is_safe_source "$cmd"; then
      return 0
    fi
    terminal_guard_add_warning "caution" "[dotfile-reference] sensitive path referenced (~/.ssh or shell rc files)"
  fi
}

# Scan a command line and populate warnings; return 0 if safe.
terminal_guard_scan_command() {
  local cmd="$1"
  terminal_guard_reset_warnings

  if [ -z "$cmd" ]; then
    return 0
  fi

  terminal_guard_check_pipe_to_shell "$cmd"
  terminal_guard_check_ansi "$cmd"
  terminal_guard_check_bidi "$cmd"
  terminal_guard_check_dotfiles "$cmd"
  terminal_guard_check_urls "$cmd"

  if [ "$TG_WARN_COUNT" -gt 0 ]; then
    return 1
  fi
  return 0
}

# Evaluate a command, prompt if needed, and return 0 to proceed.
terminal_guard_maybe_block() {
  local cmd="$1"

  if terminal_guard_should_bypass "$cmd"; then
    return 0
  fi

  if terminal_guard_scan_command "$cmd"; then
    return 0
  fi

  terminal_guard_print_warnings
  if terminal_guard_prompt; then
    return 0
  fi

  printf '%s\n' "terminal-guard: blocked" >/dev/tty
  return 1
}

# Zsh preexec hook to guard commands.
terminal_guard_preexec() {
  local cmd="$1"
  if ! terminal_guard_maybe_block "$cmd"; then
    kill -s INT $$
    return 1
  fi
  return 0
}

# Bash readline binding to guard commands.
terminal_guard_bash_accept_line() {
  local cmd="$READLINE_LINE"

  if [ -z "$cmd" ]; then
    READLINE_LINE=""
    READLINE_POINT=0
    return 0
  fi

  if terminal_guard_maybe_block "$cmd"; then
    history -s "$cmd"
    builtin eval "$cmd"
  fi

  READLINE_LINE=""
  READLINE_POINT=0
  return 0
}

# Install hooks for the current shell.
terminal_guard_install_hooks() {
  if ! terminal_guard_is_interactive; then
    return 0
  fi

  if [ -n "${ZSH_VERSION:-}" ]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook preexec terminal_guard_preexec
  elif [ -n "${BASH_VERSION:-}" ]; then
    bind -x '"\r":terminal_guard_bash_accept_line'
  fi
}

# Initialize terminal-guard with config and hooks.
terminal_guard_init() {
  if [ -n "${TERMINAL_GUARD_LOADED:-}" ]; then
    return 0
  fi
  TERMINAL_GUARD_LOADED=1

  TG_DIR="$(terminal_guard_script_dir)"
  TG_CONFUSABLES="${TG_DIR}/terminal-guard.confusables"
  if [ ! -f "$TG_CONFUSABLES" ] && [ -f "${TG_DIR}/../lib/confusables.txt" ]; then
    TG_CONFUSABLES="${TG_DIR}/../lib/confusables.txt"
  fi
  TG_VERSION_FILE="${TG_DIR}/terminal-guard.version"
  if [ ! -f "$TG_VERSION_FILE" ] && [ -f "${TG_DIR}/../VERSION" ]; then
    TG_VERSION_FILE="${TG_DIR}/../VERSION"
  fi

  if [ "${TERMINAL_GUARD_NO_HOOKS:-0}" = "1" ] || [ "${TERMINAL_GUARD_TEST:-0}" = "1" ]; then
    return 0
  fi

  terminal_guard_check_updates
  terminal_guard_install_hooks
}

terminal_guard_init
