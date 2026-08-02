# ENGINEERING_LOG — extractmail

Append-only activity log for this subproject.

## 2026-08-01 — Staging scaffold

- Created sandbox staging tree under VehicleExpenses `dev-ai-interaction/subprojects/extractmail/`
- MIT license; README; TODO (phase 2+; trainer; packaging)
- Copied Apps Script + Shell/Sam’s fixtures + reference-js parsers from `dev-ai-interaction/email-receipt/`
- Design: fetch → YAML/CSS extractors or external tool → JSON + `_meta` → optional remotetable append-only
- Retain Apps Script Gmail→Sheets path; test with same fixtures/configs
- Awaiting GitHub repo URL; formal plans deferred until then
- Dual eng-log with VehicleExpenses until dedicated agents own this repo

## 2026-08-02 — Plans retargeted to host + third_party

- Policy: VehicleExpenses docs/reference/FIRST_PARTY_LIBS.md + THIRD_PARTY_LAYOUT_FOR_AGENTS.md
- VE pin dir: third_party/extractmail/ (lock sha TBD until first real pin)
- Formal plans (VE sandbox plans/):
  - remotetable: remotetable-m1-lib-conformance-ve-pin-20260802-0348-plan.md
  - extractmail: extractmail-m1-extract-stdin-external-ve-pin-20260802-0348-plan.md
- Implement library work here (~/git/extractmail); VE only pin bumps + thin consumers
- Parallel agents: one track per lib host; avoid fighting over VE app/ except migration PRs

## 2026-08-02 - M1 stdin + YAML types + goldens

- extractors/*.yaml (shell-ereceipt, samsclub-fuel)
- python/extractmail_stdin.py + run_goldens.py
- spec OVERVIEW/EXTERNAL; goldens PASS
