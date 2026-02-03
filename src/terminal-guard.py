#!/usr/bin/env python3
"""Optional deeper analysis for terminal-guard (standard library only)."""

from __future__ import annotations

import argparse
import os
import re
import sys
from typing import Iterable, List, Tuple


URL_RE = re.compile(r"https?://[^\s\"'<>]+")
DOMAIN_RE = re.compile(r"([A-Za-z0-9-]+\.)+[A-Za-z]{2,}")
NETWORK_RE = re.compile(r"(^|\s)(curl|wget|git\s+clone)(\s|$)")


def load_confusables(path: str) -> List[Tuple[str, str, str, str]]:
    """Load confusable mappings from a tab-delimited file."""
    items: List[Tuple[str, str, str, str]] = []
    try:
        with open(path, "r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split("\t")
                if len(parts) < 4:
                    continue
                items.append((parts[0], parts[1], parts[2], parts[3]))
    except FileNotFoundError:
        return []
    return items


def extract_urls(cmd: str) -> List[str]:
    """Extract explicit URLs from a command line."""
    return URL_RE.findall(cmd)


def host_from_url(url: str) -> str:
    """Extract hostname from a URL."""
    host = re.sub(r"^[a-zA-Z]+://", "", url)
    host = host.split("/")[0]
    host = host.split("?")[0]
    host = host.split("#")[0]
    if "@" in host:
        host = host.split("@", 1)[1]
    if ":" in host:
        host = host.split(":", 1)[0]
    return host


def extract_domain_tokens(cmd: str) -> List[str]:
    """Extract domain-like tokens from a command line."""
    tokens = re.split(r"\s+", cmd)
    results = []
    for token in tokens:
        token = token.strip("\"',;")
        token = re.sub(r"^https?://", "", token)
        token = re.sub(r"^ssh://", "", token)
        if DOMAIN_RE.search(token):
            results.append(token)
    return results


def host_from_token(token: str) -> str:
    """Normalize a domain token into a hostname."""
    if "@" in token:
        token = token.split("@", 1)[1]
    token = token.split("/")[0]
    token = token.split(":", 1)[0]
    return token


def has_non_ascii(text: str) -> bool:
    """Return True if the text contains non-ASCII characters."""
    return any(ord(ch) > 127 for ch in text)


def scan_command(cmd: str, confusables: List[Tuple[str, str, str, str]]) -> List[str]:
    """Scan a command line and return warning messages."""
    warnings: List[str] = []
    for url in extract_urls(cmd):
        host = host_from_url(url)
        if host and has_non_ascii(host):
            warnings.append(f"Non-ASCII hostname in {url}: \"{host}\"")
        for char, code, latin, name in confusables:
            if char in host:
                warnings.append(
                    f"Homoglyph in host from {url}: '{char}' ({code}) mimics '{latin}' ({name})"
                )

    if NETWORK_RE.search(cmd):
        for token in extract_domain_tokens(cmd):
            host = host_from_token(token)
            if host and has_non_ascii(host):
                warnings.append(f"Non-ASCII hostname in {token}: \"{host}\"")
            for char, code, latin, name in confusables:
                if char in host:
                    warnings.append(
                        f"Homoglyph in host from {token}: '{char}' ({code}) mimics '{latin}' ({name})"
                    )
    return warnings


def main(argv: Iterable[str]) -> int:
    """CLI entrypoint."""
    parser = argparse.ArgumentParser(description="terminal-guard deep scan")
    parser.add_argument("command", nargs="*", help="command to scan")
    parser.add_argument(
        "--confusables",
        default=os.environ.get("TERMINAL_GUARD_CONFUSABLES", ""),
        help="path to confusables.txt",
    )
    args = parser.parse_args(list(argv))

    cmd = " ".join(args.command).strip()
    if not cmd:
        cmd = sys.stdin.read()

    confusables_path = args.confusables
    if not confusables_path:
        confusables_path = os.path.join(os.path.dirname(__file__), "..", "lib", "confusables.txt")
    confusables = load_confusables(confusables_path)

    warnings = scan_command(cmd, confusables)
    for warning in warnings:
        print(warning)

    return 1 if warnings else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
