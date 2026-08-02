#!/usr/bin/env python3
"""
extractmail stdin path (M1) — reference-js via Node.

Usage:
  cat fixtures/shell-receipt1.html | python3 python/extractmail_stdin.py --type shell-ereceipt
  cat fixtures/sams-club-receipt1.html | python3 python/extractmail_stdin.py --type samsclub-fuel \\
      --date-header "Fri, 31 Jul 2026 21:48:47 -0600"

Exit: 0 ok, 1 no match, 2 error
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REF_JS = ROOT / "extractors" / "reference-js"


def run_node(
    html: str,
    type_key: str,
    date_header: str | None,
    from_header: str | None,
    subject: str | None,
) -> dict | None:
    script = f"""
const fs = require('fs');
const path = require('path');
const root = {json.dumps(str(REF_JS))};
const {{ tryParseReceiptHtml }} = require(path.join(root, 'receipt-parsers.js'));
const {{ parseShellReceiptHtml }} = require(path.join(root, 'shell-receipt-parser.js'));
const {{ parseSamsClubReceiptHtml }} = require(path.join(root, 'sams-club-receipt-parser.js'));
const html = fs.readFileSync(0, 'utf8');
const meta = {{
  messageKey: 'stdin',
  emailDateHeader: {json.dumps(date_header)},
  fromHeader: {json.dumps(from_header or '')},
  subject: {json.dumps(subject or '')},
}};
let parsed = null;
const t = {json.dumps(type_key)};
if (t === 'shell-ereceipt') parsed = parseShellReceiptHtml(html, meta);
else if (t === 'samsclub-fuel') parsed = parseSamsClubReceiptHtml(html, meta);
else if (t === 'auto' || !t) parsed = tryParseReceiptHtml(html, meta);
else {{ process.stderr.write('unknown type\\n'); process.exit(2); }}
if (!parsed) process.exit(1);
const out = {{
  cost: parsed.cost,
  gallons: parsed.gallons,
  currency: parsed.currency || 'USD',
  brand: parsed.brand,
  location: parsed.locationText,
  timestamp_ms: parsed.timestampMs,
  timestamp_local: parsed.timestampLocal,
  product: parsed.product,
  pump: parsed.pump,
  site_id: parsed.siteId,
  _meta: {{
    fields: 0,
    extractor: t === 'auto' || !t ? (parsed.brand || 'auto') : t,
    version: 1,
  }},
}};
const keys = Object.keys(out).filter(k => k !== '_meta' && out[k] !== undefined && out[k] !== null && out[k] !== '');
out._meta.fields = keys.length;
process.stdout.write(JSON.stringify(out) + '\\n');
"""
    proc = subprocess.run(
        ["node", "-e", script],
        input=html.encode("utf-8"),
        capture_output=True,
    )
    if proc.returncode == 1:
        return None
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr.decode("utf-8", errors="replace")[:500])
        raise SystemExit(2)
    return json.loads(proc.stdout.decode("utf-8"))


def main() -> int:
    ap = argparse.ArgumentParser(description="extractmail stdin → JSON")
    ap.add_argument("--type", default="auto", help="shell-ereceipt | samsclub-fuel | auto")
    ap.add_argument("--date-header", default=None, help="RFC822 Date (required for Sam's)")
    ap.add_argument("--from", dest="from_header", default=None)
    ap.add_argument("--subject", default=None)
    args = ap.parse_args()
    html = sys.stdin.read()
    if not html.strip():
        sys.stderr.write("empty stdin\n")
        return 2
    try:
        out = run_node(html, args.type, args.date_header, args.from_header, args.subject)
    except SystemExit as e:
        return int(e.code) if e.code is not None else 2
    except Exception as e:
        sys.stderr.write(f"error: {e}\n")
        return 2
    if out is None:
        return 1
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
