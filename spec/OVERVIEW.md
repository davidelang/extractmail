# extractmail — Spec overview (M1)

**MIT.** Fetch → extract → JSON (+ `_meta`) → optional append via remotetable.

## Fetch sources (M1)

| Source | Status |
|--------|--------|
| **stdin** | **Required** — raw message or HTML body |
| `imap` | M1-adjacent if small; else M2 |
| `gmail` | M1-adjacent if small; else M2 |

## Output

JSON object with application fields plus:

```json
{
  "_meta": {
    "fields": 6,
    "extractor": "shell-ereceipt",
    "version": 1
  },
  "cost": 144.77,
  "gallons": 32.036,
  "currency": "USD",
  "brand": "Shell",
  "location": "...",
  "timestamp_ms": 0,
  "timestamp_local": "..."
}
```

Minimum: `_meta.fields` present (count of non-meta application keys).

## Builtin extractors

YAML keyed by type (`shell-ereceipt`, `samsclub-fuel`) with CSS/XPath **or** reference-js fallback until pure YAML is complete.

## External extractors (Linux / OpenWrt phase 1)

```text
stdin  → message or body
stdout → JSON including _meta
stderr → diagnostics only (no secrets)
exit   → 0 ok, 1 no match, 2 error
```

See `EXTERNAL.md`.

## Apps Script

`apps-script/` — zero-binary Gmail→Sheets; **same fixtures** as native extractors.

## Write path

Append-only via remotetable when available. Cursor file for live fetch position only.
