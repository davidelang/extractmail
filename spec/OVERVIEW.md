# extractmail — Spec overview (draft)

## Fetch sources

- `gmail` (API, token file)  
- `imap` (generic; Gmail IMAP should work with app password)  
- `stdin` (raw message or HTML body — for MDA/pipe)  

## Output

Single JSON object (or NDJSON later) with application fields plus:

```json
{
  "_meta": {
    "fields": 6,
    "extractor": "shell-ereceipt",
    "version": 1
  },
  "cost": 12.34,
  "gallons": 3.0
}
```

## Builtin extractors

YAML keyed by type; CSS/XPath + optional regex/money transforms.

## External extractors (Linux/OpenWrt phase 1)

```text
stdin  → message or body
stdout → JSON including _meta
stderr → diagnostics only
exit   → 0 ok, 1 no match, 2 error
```

## Write path

Append-only via remotetable (not full sync). Cursor file only for fetch position.
