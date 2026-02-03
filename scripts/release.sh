#!/usr/bin/env bash
set -euo pipefail

# Release helper: bump VERSION + TERMINAL_GUARD_VERSION, tag, and push.
release_main() {
  local new_version
  if [ $# -ne 1 ]; then
    printf '%s\n' "Usage: scripts/release.sh <version>" >&2
    return 1
  fi
  new_version="$1"

  if ! git diff --quiet || ! git diff --cached --quiet; then
    printf '%s\n' "Working tree is dirty. Commit or stash first." >&2
    return 1
  fi

  printf '%s\n' "$new_version" > VERSION

  python3 - "$new_version" <<'PY'
import sys
from pathlib import Path

version = sys.argv[1]
path = Path("src/terminal-guard.sh")
lines = path.read_text(encoding="utf-8").splitlines()
for i, line in enumerate(lines):
    if line.startswith("TERMINAL_GUARD_VERSION="):
        lines[i] = f'TERMINAL_GUARD_VERSION="{version}"'
        break
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

  git add VERSION src/terminal-guard.sh
  git commit -m "Release ${new_version}"
  git tag "v${new_version}"
  git push
  git push --tags
}

release_main "$@"
