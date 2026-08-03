# extractmail

**MIT** · Fetch mail (Gmail API, IMAP, **stdin**) → modular extractors → **JSON** (with `_meta`) → optional **append-only** write via [remotetable](../remotetable/).

Not a full spreadsheet sync engine. Cursor state only (e.g. last Message-ID / UID).

## Status

**SoT:** `~/git/extractmail` + `git@github.com:davidelang/extractmail.git`.  
**VE pin:** `third_party/extractmail/`. This sandbox copy is seed only.

| Milestone | Scope |
|-----------|--------|
| **M1** | Spec + YAML type→CSS/XPath configs; external extractor contract; stdin; JSON + `_meta.fields`; reference extractors (Shell, Sam’s Club); Apps Script ported here for shared fixtures |
| **M2** | IMAP + Gmail API fetch (token file); remotetable append |
| **M3** | Browser **trainer** (GitHub-pages friendly: open local/remote sample, export config); packaging later |
| **M4** | Dedup helpers (“skip if cost+volume+time or Sync ID exists”) |

## Layout

| Path | Role |
|------|------|
| `spec/` | JSON output schema, external tool contract, fetch sources |
| `extractors/` | Builtin configs + `reference-js/` from VE email-receipt work |
| `fixtures/` | Shell + Sam’s samples and expected JSON |
| `apps-script/` | **Gmail→Sheets** no-binary path (moved from VE sandbox email-receipt) |
| `trainer/` | Future browser-based config builder |
| `go/`, `python/` | Dual impls; same conformance idea as remotetable |

## Extractor design

- **Builtin:** type key → YAML config (CSS/XPath + transforms).
- **External (required on Linux/OpenWrt v1):** stdin body → stdout JSON → exit code; always include `_meta` (at least `fields` count).
- Prefer thin wrappers around existing HTML selector libraries, not a new full language.

## CLI (host)

```bash
scripts/extractmail --list-types
cat fixtures/shell-receipt1.html | scripts/extractmail --type shell-ereceipt
python3 python/run_goldens.py          # offline goldens + external contract 0/1/2
```

Type keys load from `extractors/*.yaml` (detect/reject metadata + `impl`/`module` pointers).  
SoT extract implementation remains **reference-js** under `extractors/reference-js/` until native ports land.

## Apps Script

Kept for **zero-binary Gmail→Sheets**. Must use the **same configs/fixtures** as native extractors
(same expected numbers as `fixtures/expected-*.json`; Apps Script not required for CI).

## VehicleExpenses

App remains callers: in-app Gmail/IMAP pollers eventually share extractmail contracts/libs; full multi-tab **sync** is remotetable’s job, not extractmail’s.

## License

MIT — see `LICENSE`.
