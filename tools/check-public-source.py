#!/usr/bin/env python3
"""Targeted public-source hygiene check, not a complete secret detector."""
from pathlib import Path
import re
import subprocess

files = subprocess.check_output(["git", "ls-files", "-z"]).decode().split("\0")
patterns = [
    rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",
    rb"\bgh[pousr]_[A-Za-z0-9]{30,}\b",
    rb"\bgithub_pat_[A-Za-z0-9_]{40,}\b",
    rb"\bAKIA[A-Z0-9]{16}\b",
    rb"\bsk-(?:proj-)?[A-Za-z0-9_-]{40,}\b",
    rb"/Users/[A-Za-z0-9_.-]+/",
]
failures = []
for name in filter(None, files):
    path = Path(name)
    if path.suffix.lower() in {".store", ".sqlite", ".db", ".p12", ".pfx", ".pem", ".key"}:
        failures.append((name, "private data/signing file"))
    data = path.read_bytes()
    for pattern in patterns:
        if re.search(pattern, data):
            failures.append((name, "credential or personal-path pattern"))
if failures:
    for name, reason in failures:
        print("FAIL", name, reason)  # Never print matched secrets.
    raise SystemExit(1)
print(f"PASS targeted hygiene scan of {len(list(filter(None, files)))} tracked files")
