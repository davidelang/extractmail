# External extractor contract

External programs let extractmail support new brands without shipping Node, and let OpenWrt/Linux hosts plug custom parsers.

## Invocation

```bash
extractmail-external --type shell-ereceipt < message.eml
# or HTML body only:
cat body.html | extractmail-external --type samsclub-fuel
# optional config path for YAML/xpath packs:
extractmail-external --type custom-brand --config /etc/extractmail/types/custom.yaml < body.html
```

Environment (overrides flags when set):

| Var | Meaning |
|-----|---------|
| `EXTRACTMAIL_TYPE` | Override `--type` |
| `EXTRACTMAIL_CONFIG` | Path to YAML config (optional; may point at a type pack dir) |
| `EXTRACTMAIL_DATE_HEADER` | Email `Date` header (RFC 2822) when body alone is not enough |
| `EXTRACTMAIL_FROM` | From header |
| `EXTRACTMAIL_SUBJECT` | Subject header |

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Matched; single JSON object on stdout |
| 1 | No match / skip (not an error — try next type or ignore message) |
| 2 | Hard error (bad args, I/O, tool crash) |

## stdout

Single JSON object. **Required:**

| Field | Notes |
|-------|--------|
| `_meta.fields` | Integer count of non-empty product fields |
| `_meta.type` | Type key that matched (e.g. `shell-ereceipt`) |
| `_meta.extractor` | Brand or tool name |

**Fuel product fields (when applicable):**

| Field | Notes |
|-------|--------|
| `cost` | Amount paid after discounts (number or numeric string) |
| `gallons` / `volume` | Fuel volume |
| `currency` | ISO 4217 preferred (`USD`) |
| `timestamp_ms` | Epoch ms |
| `location` | Human place string |
| `brand` | e.g. Shell, SamsClub |

Unknown extra keys are allowed (forward-compatible).

## stderr

Human diagnostics only. **Never** print passwords, tokens, or full app secrets.

## Config packs (YAML)

Builtin and custom types live as `extractors/*.yaml` (or a path given by `--config` / `EXTRACTMAIL_CONFIG`).

```yaml
type: custom-brand
version: 1
brand: Custom
impl: xpath          # reference-js | xpath | external
module: optional.js  # when impl=reference-js
export: parseFn
command: /usr/local/bin/my-parser   # when impl=external
fields:
  cost:
    strategy: xpath
    selector: "//td[contains(.,'Total')]/following-sibling::td[1]"
  gallons:
    strategy: css
    selector: ".fuel-gallons"
  timestamp:
    strategy: header
    name: Date
detect:
  any:
    - body_contains: "mybrand.com"
reject:
  any:
    - body_contains: "unsubscribe-only"
```

### Strategies

| strategy | Meaning |
|----------|---------|
| `reference_js` | Node module under `extractors/reference-js/` |
| `xpath` / `css` | Host HTML select (stdlib-friendly; prefers lxml/bs4 when installed) |
| `header` | Use email header (`Date` / `From` / `Subject`) |
| `external` | Exec `command` with same stdin/exit contract |

## Integration with extractmail host CLI

```bash
# Builtins (Shell + Sam's)
cat body.html | scripts/extractmail --type shell-ereceipt

# Dispatch by YAML (including external)
scripts/extractmail --type custom-brand --config ./extractors/custom-brand.yaml < body.html

# List types
scripts/extractmail --list-types
```

## Apps Script (no-install Gmail→Sheets)

See `apps-script/` — Gmail label → `Fuel - Unassigned` without Android. Shell + Sam's parsers ported as `.gs`. Same fuel contract as host JSON.

## Trainer (TODO)

Browser tool to open a sample email/file and confirm fields with a human before exporting YAML. Avoids automation treating non-visible DOM as product data. Tracked on library TODO.
