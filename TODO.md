# TODO — extractmail

## Phase 2+ (after M1 extract + stdin + external tools)

- [ ] IMAP + Gmail API fetch daemons (token file); append-only via remotetable
- [ ] Cursor persistence (last Message-ID / UIDVALIDITY+UID only)
- [ ] Dedup: skip if remote already has Sync ID and/or cost+volume+time
- [ ] Packaging: tgz/deb/rpm/OpenWrt (x86_64, aarch64 OpenWrt One, armv7l Turris Omnia classic) → LuCI → PPA later
- [ ] Browser **trainer** (`trainer/`): open via GitHub URL; load local/remote sample; user-directed field selection; download YAML config (anti-hallucination vs blind AI)
- [ ] Split trainer to its own repo if it becomes generally useful
- [ ] Gmail-via-IMAP tweaks if “generic IMAP” is insufficient
- [ ] VehicleExpenses: thin callers for email import TODOs (intent/picker) using extractmail contracts

## VehicleExpenses origin TODOs (app still owns UI/hooks)

These remain relevant in VE until callers land:

- Import fill data / expense receipts from email and/or file pickers  
- Email hook (intent or similar)  
