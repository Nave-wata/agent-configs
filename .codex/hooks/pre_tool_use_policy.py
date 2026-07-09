#!/usr/bin/env python3
"""Block dangerous shell commands before Codex runs them."""

from __future__ import annotations

import json
import re
import shlex
import sys
from typing import Any, Iterable


BLOCK_PATTERNS = [
    (re.compile(r"\bgit\s+push\s+(?:-[^\s]+\s+)*origin\s+main(?::\S*)?\b"), "Do not push directly to main. Create a feature branch and open a PR."),
    (re.compile(r"\bgit\s+push\b.*\s--force(?:-with-lease)?\b"), "Force push requires explicit user confirmation in the current turn."),
    (re.compile(r"\b(?:sudo|aws|cdk\s+deploy|cdk\s+destroy)\b"), "This policy blocks privileged or cloud-mutating commands unless handled manually."),
    (re.compile(r"\b(?:DROP|TRUNCATE)\b", re.IGNORECASE), "Destructive database operations require explicit user confirmation and must not target dev or production."),
    (re.compile(r"(^|/)\.env(?:\.|$|\s)"), "Do not read or write .env files or environment secret files."),
    (re.compile(r"(^|/)(?:id_rsa|id_ed25519|[^/\s]+\.(?:key|pem))(?:$|\s)"), "Do not read or write private key or certificate secret files."),
]


def iter_strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from iter_strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from iter_strings(item)


def extract_commands(payload: Any, raw: str) -> list[str]:
    candidates = []
    if isinstance(payload, dict):
        for key in ("command", "cmd", "script", "shell_command"):
            if isinstance(payload.get(key), str):
                candidates.append(payload[key])
        tool_input = payload.get("tool_input")
        if isinstance(tool_input, dict):
            for key in ("command", "cmd", "script", "shell_command"):
                if isinstance(tool_input.get(key), str):
                    candidates.append(tool_input[key])

    candidates.extend(s for s in iter_strings(payload) if looks_like_command(s))
    if not candidates and raw.strip():
        candidates.append(raw)

    return list(dict.fromkeys(candidates))


def looks_like_command(value: str) -> bool:
    try:
        first = shlex.split(value)[0]
    except Exception:
        return False

    return first in {"git", "bash", "sh", "zsh", "sudo", "aws", "cdk", "mysql", "psql", "php", "composer", "cat", "sed", "grep", "rg"}


def main() -> int:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        payload = raw

    for command in extract_commands(payload, raw):
        for pattern, message in BLOCK_PATTERNS:
            if pattern.search(command):
                print(f"Blocked by .codex policy: {message}\nCommand: {command}", file=sys.stderr)
                return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

