#!/usr/bin/env python3
"""Check rejection before SwiftData opens; never opens or reads personal data."""
import os
from pathlib import Path
import subprocess
import tempfile

binary = Path.home() / "Applications/FocusNote.app/Contents/MacOS/FocusNote"
root = Path(tempfile.mkdtemp(prefix="FocusNote-safety-"))
personal = Path.home() / "Library/Application Support/FocusNote/FocusNote.store"


def rejected(label, store, extra=None, args=None):
    environment = {k: v for k, v in os.environ.items() if not k.startswith("APP_")}
    environment.update(extra or {})
    if store is not None:
        environment["APP_STORE"] = str(store)
    result = subprocess.run(
        [str(binary), *(args or [])], env=environment,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15,
    )
    assert result.returncode == 1, (label, result.returncode)
    assert b"Automation refused:" in result.stderr, label
    print("PASS", label)


rejected("self-test requires a store override", None, args=["--selftest"])
rejected("self-test refuses personal store", personal, args=["--selftest"])
rejected("seed refuses personal store", personal, {"APP_SEED": "1"})
rejected("performance probe refuses personal store", personal, args=["--timer-performance"])
rejected("snapshot refuses personal store", personal, {"APP_SNAPSHOT": str(root / "shots")})
link = root / "escape"
link.symlink_to(personal.parent, target_is_directory=True)
rejected("parent symlink escape refused", link / "FocusNote.store", args=["--selftest"])
sidecar = root / "test.store-wal"
sidecar.symlink_to(root / "untouched")
rejected("SQLite sidecar symlink refused", root / "test.store", args=["--selftest"])
sidecar.unlink()
shared = root / "shared"
shared.mkdir(mode=0o755)
rejected("shared database parent refused", shared / "test.store", args=["--selftest"])
output_link = root / "shots-link"
output_link.symlink_to(root.parent, target_is_directory=True)
rejected("snapshot output symlink escape refused", root / "test.store",
         {"APP_SNAPSHOT": str(output_link)})
assert not (root / "test.store").exists(), "Rejected automation created a store"
print("PASS all rejected modes exit before database creation")
