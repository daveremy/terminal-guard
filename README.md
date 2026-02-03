# terminal-guard

[![CI](https://github.com/daveremy/terminal-guard/actions/workflows/ci.yml/badge.svg)](https://github.com/daveremy/terminal-guard/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A minimal, auditable terminal hook that warns you before running risky commands: homoglyph URLs, pipe-to-shell, ANSI escape tricks, bidi overrides, and dotfile writes.

**Why:** homograph attacks make URLs look identical while using Cyrillic/Greek letters (e.g., `https://exаmple.com` where the `а` is Cyrillic, not Latin).

Inspired by tirith (https://github.com/sheeki03/tirith) — I wanted a minimal, auditable version I could fully understand and trust.

## What it catches

- **Homoglyphs in hostnames** (Cyrillic/Greek lookalikes) and any non-ASCII hostname characters
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
- Scans commands for URLs and known risky patterns.
- If something looks suspicious, it prints exact detections and asks for confirmation.

## Examples

- `curl https://exаmple.com/install.sh` → warns about Cyrillic `а` (U+0430)
- `curl https://example.com | bash` → warns about pipe-to-shell
- `echo 'ssh-rsa ...' >> ~/.ssh/authorized_keys` → warns about dotfile write

## Bypass (one command)

If you trust a command and want to skip the guard just once:

```bash
TERMINAL_GUARD=0 curl https://example.com | bash
```

## Updates

terminal-guard can **optionally** check for updates once per week on shell startup and print a notice. It does **not** auto-update.

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
export TERMINAL_GUARD_UPDATE_INTERVAL=86400  # daily
```

## Uninstall

```bash
./uninstall.sh
```

## Testing

```bash
./test/test-commands.sh
```

## License

MIT — see `LICENSE`.
