#!/usr/bin/env python3
"""Assert external contract exit codes 0/1/2 via external_contract_example.sh."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIX = ROOT / "fixtures"
SH = Path(__file__).resolve().parent / "external_contract_example.sh"


def run(typ: str, body: bytes) -> int:
    p = subprocess.run(
        ["bash", str(SH), typ],
        input=body,
        capture_output=True,
    )
    return p.returncode


def main() -> int:
    shell = FIX / "shell-receipt1.html"
    if not shell.is_file() or shell.stat().st_size == 0:
        shell = FIX / "shell-receipt1"
    sams = FIX / "sams-club-receipt1.html"
    # 0: match
    c0 = run("shell-ereceipt", shell.read_bytes())
    assert c0 == 0, f"expected 0 got {c0}"
    # 1: no match
    c1 = run("shell-ereceipt", sams.read_bytes())
    assert c1 == 1, f"expected 1 got {c1}"
    # 2: empty / error path
    c2 = run("shell-ereceipt", b"")
    assert c2 == 2, f"expected 2 got {c2}"
    print("PASS external contract exits 0/1/2")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print("FAIL:", e, file=sys.stderr)
        raise SystemExit(1)
