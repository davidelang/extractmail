# External extractor contract (M1)

## Invocation

```bash
extractmail-external --type shell-ereceipt < message.eml
# or
cat body.html | extractmail-external --type samsclub-fuel
```

Environment:

| Var | Meaning |
|-----|---------|
| `EXTRACTMAIL_TYPE` | Override `--type` |
| `EXTRACTMAIL_CONFIG` | Path to YAML config (optional) |

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Matched; JSON on stdout |
| 1 | No match / skip (not an error) |
| 2 | Hard error (parse failure of tool, I/O) |

## stdout

Single JSON object. Must include `_meta` with at least `fields` (integer).

## stderr

Human diagnostics only. **Never** print passwords, tokens, or full app secrets.
