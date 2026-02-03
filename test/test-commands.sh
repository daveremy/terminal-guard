#!/usr/bin/env bash
set -euo pipefail

export TERMINAL_GUARD_TEST=1
export TERMINAL_GUARD_NO_HOOKS=1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the guard implementation for testing.
# shellcheck source=../src/terminal-guard.sh
source "$PROJECT_DIR/src/terminal-guard.sh"

pass=0
fail=0

while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    \#*) continue ;;
  esac

  expected="${line%%:*}"
  cmd="${line#*: }"
  cmd="$(printf '%b' "$cmd")"

  if terminal_guard_scan_command "$cmd"; then
    actual="OK"
  else
    actual="WARN"
  fi

  if [ "$actual" = "$expected" ]; then
    pass=$((pass + 1))
    printf '%s\n' "PASS: $cmd"
  else
    fail=$((fail + 1))
    printf '%s\n' "FAIL: $cmd (expected $expected, got $actual)"
  fi
done < "$PROJECT_DIR/test/test-samples.txt"

printf '%s\n' "Passed: $pass"
printf '%s\n' "Failed: $fail"

if [ "$fail" -ne 0 ]; then
  exit 1
fi
