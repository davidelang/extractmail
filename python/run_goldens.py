#!/usr/bin/env python3
"""Conformance: Shell + Sam's goldens via extractmail_stdin."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIX = ROOT / "fixtures"
SCRIPT = Path(__file__).resolve().parent / "extractmail_stdin.py"


def run(args: list[str], data: bytes) -> tuple[int, str]:
    p = subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        input=data,
        capture_output=True,
    )
    return p.returncode, p.stdout.decode("utf-8", errors="replace")


def check(name: str, path: Path, cost: float, gal: float, extra: list[str] | None = None) -> None:
    extra = extra or []
    body = path.read_bytes()
    code, out = run(["--type", name.split(":")[0], *extra], body)
    # name format type:label
    typ, label = name.split(":", 1)
    code, out = run(["--type", typ, *extra], body)
    if code != 0:
        raise AssertionError(f"{label}: exit {code}")
    data = json.loads(out)
    assert abs(data["cost"] - cost) < 1e-6, (label, data["cost"], cost)
    assert abs(data["gallons"] - gal) < 1e-6, (label, data["gallons"], gal)
    assert "_meta" in data and "fields" in data["_meta"]
    print("PASS", label, "cost", data["cost"], "gal", data["gallons"], "fields", data["_meta"]["fields"])


def main() -> int:
    shell1 = FIX / "shell-receipt1.html"
    shell2 = FIX / "shell-receipt2.html"
    if not shell1.is_file() or shell1.stat().st_size == 0:
        shell1 = FIX / "shell-receipt1"
    if not shell2.is_file() or shell2.stat().st_size == 0:
        shell2 = FIX / "shell-receipt2"
    sams = FIX / "sams-club-receipt1.html"

    check("shell-ereceipt:shell1", shell1, 144.77, 32.036)
    check("shell-ereceipt:shell2", shell2, 52.34, 13.12)
    check(
        "samsclub-fuel:sams1",
        sams,
        136.30,
        29.069,
        [
            "--date-header",
            "Fri, 31 Jul 2026 21:48:47 -0600",
            "--from",
            "transaction@info.samsclub.com",
            "--subject",
            "Here's your fuel station receipt",
        ],
    )
    # cross reject
    code, _ = run(["--type", "shell-ereceipt"], sams.read_bytes())
    assert code == 1, f"sams-as-shell should exit 1, got {code}"
    print("PASS cross-reject sams-as-shell")
    # external contract exits
    ext = subprocess.run(
        [sys.executable, str(Path(__file__).resolve().parent / "run_external_contract.py")],
        capture_output=True,
        text=True,
    )
    if ext.returncode != 0:
        raise AssertionError(ext.stdout + ext.stderr)
    print(ext.stdout.strip())
    print("PASS all extractmail goldens")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print("FAIL:", e, file=sys.stderr)
        raise SystemExit(1)
