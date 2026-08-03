#!/usr/bin/env python3
"""Host fetch: IMAP (and Gmail-via-IMAP) → extract → optional JSONL / remotetable append.

Google OAuth interactive flows need a human token; this CLI accepts --token-file /
app-password files so automation can run under cron when credentials exist.

Usage examples:
  python3 python/fetch_mail.py imap --host imap.gmail.com --user u --password-file ~/.secret \\
      --folder INBOX --type auto --max 20 --out /tmp/receipts.jsonl

  python3 python/fetch_mail.py imap ... --append-remotetable \\
      --rt-backend ethercalc --rt-base-url http://127.0.0.1:8000 --rt-room fuel-unassigned
"""

from __future__ import annotations

import argparse
import email
import imaplib
import json
import os
import subprocess
import sys
from email.header import decode_header
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _decode_mime(s: str | None) -> str:
    if not s:
        return ""
    parts = decode_header(s)
    out = []
    for data, charset in parts:
        if isinstance(data, bytes):
            out.append(data.decode(charset or "utf-8", errors="replace"))
        else:
            out.append(str(data))
    return "".join(out)


def _html_from_message(msg: email.message.Message) -> str:
    if msg.is_multipart():
        for part in msg.walk():
            ctype = part.get_content_type()
            if ctype == "text/html":
                payload = part.get_payload(decode=True) or b""
                charset = part.get_content_charset() or "utf-8"
                return payload.decode(charset, errors="replace")
        for part in msg.walk():
            if part.get_content_type() == "text/plain":
                payload = part.get_payload(decode=True) or b""
                charset = part.get_content_charset() or "utf-8"
                return payload.decode(charset, errors="replace")
    payload = msg.get_payload(decode=True) or b""
    charset = msg.get_content_charset() or "utf-8"
    return payload.decode(charset, errors="replace")


def extract_body(html: str, type_key: str, date_header: str, from_h: str, subject: str) -> dict | None:
    cmd = [
        sys.executable,
        str(ROOT / "python" / "extractmail_stdin.py"),
        "--type",
        type_key,
    ]
    if date_header:
        cmd += ["--date-header", date_header]
    if from_h:
        cmd += ["--from", from_h]
    if subject:
        cmd += ["--subject", subject]
    proc = subprocess.run(cmd, input=html.encode("utf-8"), capture_output=True)
    if proc.returncode == 1:
        return None
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr.decode("utf-8", errors="replace")[:400])
        return None
    return json.loads(proc.stdout.decode("utf-8"))


def fuel_row_from_parsed(parsed: dict, message_id: str) -> list[str]:
    """Minimal Fuel - Unassigned row aligned with common TabularSchema order (best-effort)."""
    # Sync ID, Vehicle Sync ID, Timestamp, Cost, Gallons, Odometer, Partial Fill, Economy Ignored, ...
    sync = f"email|imap|{message_id}" if message_id else f"email|imap|{parsed.get('timestamp_ms')}"
    cost = str(parsed.get("cost") or "")
    gallons = str(parsed.get("gallons") or parsed.get("volume") or "")
    ts = str(parsed.get("timestamp_ms") or "")
    return [sync, "", ts, cost, gallons, "0", "false", "false"]


def append_remotetable(args: argparse.Namespace, headers: list[str], rows: list[list[str]]) -> None:
    # Prefer VE-linked remotetable python if present
    candidates = [
        ROOT.parent.parent / "remotetable" / "src" / "scripts" / "remotetable",
        Path("/home/dlang/git/VehicleExpenses-automated/agent-4/third_party/remotetable/src/scripts/remotetable"),
        Path.home() / "git" / "remotetable" / "scripts" / "remotetable",
    ]
    script = next((c for c in candidates if c.is_file()), None)
    if script is None:
        # try python -m
        env = os.environ.copy()
        rt_py = ROOT.parent.parent / "remotetable" / "src" / "python"
        if rt_py.is_dir():
            env["PYTHONPATH"] = str(rt_py) + (os.pathsep + env["PYTHONPATH"] if env.get("PYTHONPATH") else "")
        payload = json.dumps({"headers": headers, "rows": rows})
        cmd = [
            sys.executable,
            "-m",
            "remotetable",
            "--backend",
            args.rt_backend,
            "write-rows",
            "--tab",
            args.rt_tab,
            "--mode",
            "append",
        ]
        if args.rt_base_url:
            cmd = [
                sys.executable,
                "-m",
                "remotetable",
                "--backend",
                args.rt_backend,
                "--base-url",
                args.rt_base_url,
                "--room",
                args.rt_room or "sheet",
                "write-rows",
                "--tab",
                args.rt_tab,
                "--mode",
                "append",
            ]
        proc = subprocess.run(cmd, input=payload.encode("utf-8"), env=env, capture_output=True)
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.decode()[:400] or "remotetable write failed")
        return

    payload = json.dumps({"headers": headers, "rows": rows})
    cmd = [str(script), "--backend", args.rt_backend]
    if args.rt_token_file:
        cmd += ["--token-file", args.rt_token_file]
    if args.rt_base_url:
        cmd += ["--base-url", args.rt_base_url]
    if args.rt_room:
        cmd += ["--room", args.rt_room]
    cmd += ["write-rows", "--tab", args.rt_tab, "--mode", "append"]
    proc = subprocess.run(cmd, input=payload.encode("utf-8"), capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.decode()[:400] or "remotetable write failed")


def cmd_imap(args: argparse.Namespace) -> int:
    password = ""
    if args.password_file:
        password = Path(args.password_file).read_text(encoding="utf-8").strip()
    elif args.password:
        password = args.password
    else:
        sys.stderr.write("need --password-file or --password\n")
        return 2

    M = imaplib.IMAP4_SSL(args.host, args.port)
    M.login(args.user, password)
    typ, _ = M.select(args.folder)
    if typ != "OK":
        sys.stderr.write(f"select failed: {args.folder}\n")
        return 2

    # newest first
    typ, data = M.search(None, "ALL")
    if typ != "OK":
        return 2
    ids = data[0].split()
    ids = list(reversed(ids))[: args.max]

    out_rows: list[dict] = []
    fuel_rows: list[list[str]] = []
    for num in ids:
        typ, msg_data = M.fetch(num, "(RFC822)")
        if typ != "OK" or not msg_data or not msg_data[0]:
            continue
        raw = msg_data[0][1]
        msg = email.message_from_bytes(raw)
        mid = (msg.get("Message-ID") or msg.get("Message-Id") or num.decode()).strip()
        date_h = msg.get("Date") or ""
        from_h = _decode_mime(msg.get("From"))
        subject = _decode_mime(msg.get("Subject"))
        html = _html_from_message(msg)
        parsed = extract_body(html, args.type, date_h, from_h, subject)
        if not parsed:
            continue
        parsed.setdefault("_meta", {})
        parsed["_meta"]["message_id"] = mid
        parsed["_meta"]["subject"] = subject
        out_rows.append(parsed)
        fuel_rows.append(fuel_row_from_parsed(parsed, mid))

    M.logout()

    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            for row in out_rows:
                f.write(json.dumps(row) + "\n")
        print(f"wrote {len(out_rows)} records to {args.out}")
    else:
        print(json.dumps({"count": len(out_rows), "records": out_rows}, indent=2))

    if args.append_remotetable and fuel_rows:
        headers = [
            "Sync ID",
            "Vehicle Sync ID",
            "Timestamp",
            "Cost",
            "Gallons",
            "Odometer",
            "Partial Fill",
            "Economy Ignored",
        ]
        append_remotetable(args, headers, fuel_rows)
        print(f"appended {len(fuel_rows)} rows via remotetable")

    return 0


def main() -> int:
    ap = argparse.ArgumentParser(prog="extractmail-fetch")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("imap", help="IMAP folder poll → extract")
    p.add_argument("--host", required=True)
    p.add_argument("--port", type=int, default=993)
    p.add_argument("--user", required=True)
    p.add_argument("--password-file", default=None)
    p.add_argument("--password", default=None, help="prefer --password-file")
    p.add_argument("--folder", default="INBOX")
    p.add_argument("--type", default="auto")
    p.add_argument("--max", type=int, default=50)
    p.add_argument("--out", default=None, help="JSONL output path")
    p.add_argument("--append-remotetable", action="store_true")
    p.add_argument("--rt-backend", default="ethercalc")
    p.add_argument("--rt-base-url", default=None)
    p.add_argument("--rt-room", default="sheet")
    p.add_argument("--rt-tab", default="Fuel - Unassigned")
    p.add_argument("--rt-token-file", default=None)
    p.set_defaults(func=cmd_imap)

    g = sub.add_parser("gmail-oauth", help="placeholder: needs human token (see docs)")
    g.set_defaults(func=lambda a: (_gmail_help(), 2)[1])

    args = ap.parse_args()
    return int(args.func(args) or 0)


def _gmail_help() -> None:
    sys.stderr.write(
        "Gmail OAuth interactive flow requires a human-provided token file.\n"
        "Use: imap --host imap.gmail.com with an app password, or pass tokens later.\n"
    )


if __name__ == "__main__":
    raise SystemExit(main())
