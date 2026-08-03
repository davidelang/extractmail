#!/usr/bin/env python3
"""
extractmail stdin path — reference-js via Node; type keys from extractors/*.yaml.

YAML fields `impl`, `module`, `export` select the Node entry (no hardcoded type→fn map
for known registry types). `auto` uses receipt-parsers tryParse.

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
sys.path.insert(0, str(Path(__file__).resolve().parent))
from type_registry import known_types, load_type_registry, resolve_impl  # noqa: E402
from xpath_extract import extract_from_yaml_fields  # noqa: E402


def run_node_auto(
    html: str,
    date_header: str | None,
    from_header: str | None,
    subject: str | None,
) -> dict | None:
    script = f"""
const fs = require('fs');
const path = require('path');
const root = {json.dumps(str(REF_JS))};
const {{ tryParseReceiptHtml }} = require(path.join(root, 'receipt-parsers.js'));
const html = fs.readFileSync(0, 'utf8');
const meta = {{
  messageKey: 'stdin',
  emailDateHeader: {json.dumps(date_header)},
  fromHeader: {json.dumps(from_header or '')},
  subject: {json.dumps(subject or '')},
}};
const parsed = tryParseReceiptHtml(html, meta);
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
  _meta: {{ fields: 0, extractor: parsed.brand || 'auto', version: 1, type: 'auto' }},
}};
const keys = Object.keys(out).filter(k => k !== '_meta' && out[k] !== undefined && out[k] !== null && out[k] !== '');
out._meta.fields = keys.length;
process.stdout.write(JSON.stringify(out) + '\\n');
"""
    return _node(script, html)


def run_node_yaml(
    html: str,
    type_key: str,
    module: str,
    export: str,
    date_header: str | None,
    from_header: str | None,
    subject: str | None,
) -> dict | None:
    script = f"""
const fs = require('fs');
const path = require('path');
const root = {json.dumps(str(REF_JS))};
const mod = require(path.join(root, {json.dumps(module)}));
const fn = mod[{json.dumps(export)}] || mod.default;
if (typeof fn !== 'function') {{
  process.stderr.write('export not a function: ' + {json.dumps(export)} + '\\n');
  process.exit(2);
}}
const html = fs.readFileSync(0, 'utf8');
const meta = {{
  messageKey: 'stdin',
  emailDateHeader: {json.dumps(date_header)},
  fromHeader: {json.dumps(from_header or '')},
  subject: {json.dumps(subject or '')},
}};
const parsed = fn(html, meta);
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
    extractor: {json.dumps(type_key)},
    version: 1,
    type: {json.dumps(type_key)},
    module: {json.dumps(module)},
    export: {json.dumps(export)},
  }},
}};
const keys = Object.keys(out).filter(k => k !== '_meta' && out[k] !== undefined && out[k] !== null && out[k] !== '');
out._meta.fields = keys.length;
process.stdout.write(JSON.stringify(out) + '\\n');
"""
    return _node(script, html)


def _node(script: str, html: str) -> dict | None:
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


def run_external(command: str, html: str, type_key: str, env_extra: dict[str, str]) -> dict | None:
    import os

    env = os.environ.copy()
    env["EXTRACTMAIL_TYPE"] = type_key
    env.update(env_extra)
    proc = subprocess.run(
        command if isinstance(command, list) else ["bash", "-lc", command],
        input=html.encode("utf-8"),
        capture_output=True,
        env=env,
    )
    if proc.returncode == 1:
        return None
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr.decode("utf-8", errors="replace")[:500])
        raise SystemExit(2)
    text = proc.stdout.decode("utf-8").strip()
    if not text:
        raise SystemExit(2)
    return json.loads(text)


def run_xpath_pack(html: str, reg: dict, type_key: str, headers: dict[str, str]) -> dict | None:
    fields = reg.get("fields") or {}
    if not isinstance(fields, dict):
        return None
    extracted = extract_from_yaml_fields(html, fields, headers)
    if not extracted:
        return None
    out: dict = dict(extracted)
    # normalize cost/gallons keys
    if "cost" not in out and "amount" in out:
        out["cost"] = out["amount"]
    if "gallons" not in out and "volume" in out:
        out["gallons"] = out["volume"]
    if reg.get("brand"):
        out.setdefault("brand", reg["brand"])
    if reg.get("currency"):
        out.setdefault("currency", reg["currency"])
    keys = [k for k, v in out.items() if v not in (None, "") and k != "_meta"]
    out["_meta"] = {
        "fields": len(keys),
        "extractor": reg.get("brand") or type_key,
        "version": reg.get("version") or 1,
        "type": type_key,
        "impl": "xpath",
    }
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="extractmail stdin → JSON")
    ap.add_argument("--type", default="auto", help="type key from extractors/*.yaml, or auto")
    ap.add_argument("--list-types", action="store_true", help="print known YAML types and exit")
    ap.add_argument("--date-header", default=None, help="RFC822 Date (required for Sam's)")
    ap.add_argument("--from", dest="from_header", default=None)
    ap.add_argument("--subject", default=None)
    ap.add_argument("--config", default=None, help="optional extra YAML type path or EXTRACTMAIL_CONFIG")
    args = ap.parse_args()

    if args.list_types:
        for t in known_types():
            meta = load_type_registry()[t]
            print(
                f"{t}\timpl={meta.get('impl')}\tmodule={meta.get('module')}\t"
                f"export={meta.get('export')}\tbrand={meta.get('brand')}"
            )
        return 0

    if args.type in ("auto", ""):
        html = sys.stdin.read()
        if not html.strip():
            sys.stderr.write("empty stdin\n")
            return 2
        try:
            out = run_node_auto(html, args.date_header, args.from_header, args.subject)
        except SystemExit as e:
            return int(e.code) if e.code is not None else 2
        except Exception as e:
            sys.stderr.write(f"error: {e}\n")
            return 2
        if out is None:
            return 1
        print(json.dumps(out, indent=2))
        return 0

    reg = resolve_impl(args.type)
    # optional --config path for a single type file
    if args.config:
        from pathlib import Path
        from type_registry import _simple_yaml_load

        p = Path(args.config)
        if p.is_file():
            data = _simple_yaml_load(p.read_text(encoding="utf-8"))
            if data:
                reg = data
                reg.setdefault("type", args.type)

    if reg is None:
        sys.stderr.write(f"unknown type {args.type!r}; known: {', '.join(known_types())}\n")
        return 2

    impl = str(reg.get("impl") or "reference-js").lower().replace("_", "-")
    html = sys.stdin.read()
    if not html.strip():
        sys.stderr.write("empty stdin\n")
        return 2

    headers = {
        "Date": args.date_header or "",
        "From": args.from_header or "",
        "Subject": args.subject or "",
    }

    try:
        if impl in ("reference-js", "referencejs"):
            module = str(reg.get("module") or "").strip()
            export = str(reg.get("export") or "").strip()
            if not module or not export:
                sys.stderr.write(f"type {args.type!r} missing module/export in YAML\n")
                return 2
            out = run_node_yaml(
                html, args.type, module, export, args.date_header, args.from_header, args.subject
            )
        elif impl in ("xpath", "css", "yaml-fields"):
            out = run_xpath_pack(html, reg, args.type, headers)
        elif impl == "external":
            cmd = str(reg.get("command") or "").strip()
            if not cmd:
                sys.stderr.write(f"type {args.type!r} impl=external missing command\n")
                return 2
            env_extra = {}
            if args.date_header:
                env_extra["EXTRACTMAIL_DATE_HEADER"] = args.date_header
            if args.from_header:
                env_extra["EXTRACTMAIL_FROM"] = args.from_header
            if args.subject:
                env_extra["EXTRACTMAIL_SUBJECT"] = args.subject
            out = run_external(cmd, html, args.type, env_extra)
        else:
            sys.stderr.write(f"unsupported impl {impl!r} for type {args.type!r}\n")
            return 2
    except SystemExit as e:
        return int(e.code) if e.code is not None else 2
    except Exception as e:
        sys.stderr.write(f"error: {e}\n")
        return 2
    if out is None:
        return 1
    # Ensure brand from YAML when present
    if reg.get("brand") and not out.get("brand"):
        out["brand"] = reg["brand"]
    if reg.get("brand"):
        out.setdefault("_meta", {})
        out["_meta"]["brand"] = reg["brand"]
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
