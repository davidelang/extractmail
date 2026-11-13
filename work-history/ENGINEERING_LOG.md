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


## 2026-08-02 - M1 Android AAR surface

- android/ library module extractmail.aar API surface


## 2026-08-02 - M2 YAML type registry + CLI wrapper + external contract

- type_registry from extractors/*.yaml; extractmail_stdin loads types
- scripts/extractmail wrapper; run_external_contract 0/1/2 in goldens
- AAR VERSION=2 + TYPE_* constants (host CLI extract only)

## 2026-08-02 - M2.5 YAML impl dispatch + offline golden export

- extractmail_stdin dispatches via YAML module/export (no type if-chain)
- scripts/export_offline_goldens.sh for VE assets packaging

## 2026-08-03 - PR prepared: sandbox/PRs/PR-email-connection.md (rebase onto master; goldens+AAR OK)

## 2026-11-12 - libpin kit 2026.10.24

- Synced the libpin kit (fetch-deps, get-artifacts, VERSION, libpin-sandbox, libpin-bwrap, libpin-landlock) from orchestration-example@830b09e (libpin@1a98c91, LIBPIN_VERSION 2026.10.24).
- .gitignore un-ignores third_party/VERSION (and the other kit tools where they were still ignored).
- Pin tomls updated as needed for the new kit (example: source_kind=seed-src, default=false, sha256; heavy pins rclone/paddle/paddle-opt/opencv: default=false).

