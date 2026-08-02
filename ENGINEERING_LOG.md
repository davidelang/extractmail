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

## 2026-08-02 — third_party live; plans retargeted

- VE branch has third_party/extractmail with lock.yaml (sha TBD until first pin)
- Host: ~/git/extractmail — GitHub davidelang/extractmail
- Formal plans under dev-ai-interaction/plans/*-20260802-0348-plan.md
- Continue email/tabular work via library host + VE pin bumps only

## 2026-08-02 - M1 stdin extractors + goldens

- YAML shell-ereceipt + samsclub-fuel; python extractmail_stdin + run_goldens PASS
- Spec EXTERNAL; branch email-connection

