# terminal-guard

[![CI](https://github.com/daveremy/terminal-guard/actions/workflows/ci.yml/badge.svg)](https://github.com/daveremy/terminal-guard/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A minimal, auditable terminal guard that warns before running risky commands: homoglyph URLs, pipe-to-shell, ANSI escape tricks, bidirectional overrides, dotfile writes, and punycode (IDN) hostnames.

**Why:** homograph attacks make URLs look identical while using Cyrillic/Greek letters (e.g., `https://exаmple.com` where the `а` is Cyrillic, not Latin).

Inspired by tirith (https://github.com/sheeki03/tirith) — I wanted a minimal, auditable version I could fully understand and trust.

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/daveremy/terminal-guard/main/install.sh | bash
source ~/.zshrc  # or source ~/.bashrc
```

Test it:

```bash
curl https://exаmple.com/install.sh
```

## What it catches

- **Homoglyphs in hostnames** (Cyrillic/Greek lookalikes) and any **non-ASCII** hostname characters
- **Punycode hostnames** (`xn--` labels) to flag IDNs
- **Pipe-to-shell** patterns like `curl ... | bash` or `wget ... | sh`
- **ANSI escape sequences** that can hide or rewrite displayed text
- **Bidirectional overrides** (RTL/LTR controls) that can spoof display order
- **Sensitive dotfile writes** (e.g., `~/.ssh/`, `~/.bashrc`, `~/.zshrc`, `~/.gitconfig`)

## Installation

### Git clone (recommended)

```bash
git clone https://github.com/daveremy/terminal-guard.git
cd terminal-guard
./install.sh
```

### curl (less ideal)

```bash
curl -fsSL https://raw.githubusercontent.com/daveremy/terminal-guard/main/install.sh | bash
```

Yes, the irony is noted. If you use `curl | bash`, read the script first or clone the repo.

## How it works (short version)

- Hooks into your shell (bash via a readline binding, zsh via `preexec`).
- Scans commands for URLs and risky patterns.
- If something looks suspicious, it prints exact detections and asks for confirmation.
- Default is **No**, with a **double-confirm** on Yes.

## Examples

- `curl https://exаmple.com/install.sh` → warns about Cyrillic `а` (U+0430)
- `curl https://example.com | bash` → warns about pipe-to-shell
- `echo 'ssh-rsa ...' >> ~/.ssh/authorized_keys` → warns about dotfile write
- `curl https://xn--exmple-cua.com` → warns about punycode

## Bypass (one command)

If you trust a command and want to skip the guard just once:

```bash
TERMINAL_GUARD=0 curl https://example.com | bash
```

## Updates

terminal-guard can **optionally** check for updates once per day on shell startup and print a notice. It does **not** auto-update.

Update now:

```bash
terminal-guard-update
```

Disable update checks:

```bash
export TERMINAL_GUARD_UPDATE_CHECK=0
```

Change the interval (seconds):

```bash
export TERMINAL_GUARD_UPDATE_INTERVAL=86400  # daily (default)
```

## Testing

```bash
./test/test-commands.sh
./test/test-update.sh
```

Or use Make:

```bash
make test
make lint
make check
```

## Troubleshooting

### Guard not prompting

- Make sure it’s loaded:

```bash
grep -n "terminal-guard" ~/.zshrc ~/.bashrc
```

- If `TERMINAL_GUARD=0` is set, the guard is disabled. Clear it:

```bash
unset TERMINAL_GUARD
exec $SHELL -l
```

- If you ran `TERMINAL_GUARD=0 source ~/.zshrc`, that setting persists in the current shell.

### Update command errors

If `terminal-guard-update` errors, reinstall once via curl to refresh the updater:

```bash
TERMINAL_GUARD=0 curl -fsSL https://raw.githubusercontent.com/daveremy/terminal-guard/main/install.sh | bash
```

## FAQ

**Why does it warn on `curl | bash`?**

That pattern is risky even with legitimate URLs. Download and inspect first.

**Why are punycode domains flagged?**

Punycode (`xn--`) hides non-ASCII characters. It is often legit, but also used in homograph attacks.

**Why is the default answer No?**

This is a safety tool — any ambiguity should fail safe.

## Uninstall

```bash
./uninstall.sh
```

## License

MIT — see `LICENSE`.
