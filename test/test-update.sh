#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

pass=0
fail=0

# Run a single update test case.
run_case() {
  local label="$1"
  shift
  local output

  if output="$($@)"; then
    echo "PASS: $label"
    echo "$output" | sed 's/^/  /'
    pass=$((pass + 1))
  else
    echo "FAIL: $label"
    echo "$output" | sed 's/^/  /'
    fail=$((fail + 1))
  fi
}

# Create a temp HOME and fake repo for update tests.
setup_fake_repo() {
  local tmp_root="$1"
  local repo_dir
  repo_dir="$tmp_root/repo"
  mkdir -p "$repo_dir"
  printf '%s\n' "$2" >"$repo_dir/VERSION"
  cat <<'EOS' >"$repo_dir/install.sh"
#!/usr/bin/env bash
set -euo pipefail
echo "STUB INSTALL RUN"
EOS
  chmod 755 "$repo_dir/install.sh"
  printf '%s\n' "$repo_dir"
}

# Test: update script reports up-to-date and does not run installer.
case_up_to_date() {
  local tmp_root repo_dir
  tmp_root="$(mktemp -d)"
  repo_dir="$(setup_fake_repo "$tmp_root" "0.1.7")"
  mkdir -p "$tmp_root/.local/bin"
  printf '%s\n' "0.1.7" >"$tmp_root/.local/bin/terminal-guard.version"

  HOME="$tmp_root" \
  TERMINAL_GUARD_REPO="file://$repo_dir" \
  bash "$PROJECT_DIR/src/terminal-guard-update.sh"
}

# Test: update script runs installer when newer version exists.
case_update_available() {
  local tmp_root repo_dir
  tmp_root="$(mktemp -d)"
  repo_dir="$(setup_fake_repo "$tmp_root" "0.1.8")"
  mkdir -p "$tmp_root/.local/bin"
  printf '%s\n' "0.1.7" >"$tmp_root/.local/bin/terminal-guard.version"

  HOME="$tmp_root" \
  TERMINAL_GUARD_REPO="file://$repo_dir" \
  bash "$PROJECT_DIR/src/terminal-guard-update.sh"
}

run_case "up-to-date" case_up_to_date
run_case "update-available" case_update_available

printf '%s\n' "Passed: $pass"
printf '%s\n' "Failed: $fail"

if [ "$fail" -ne 0 ]; then
  exit 1
fi
