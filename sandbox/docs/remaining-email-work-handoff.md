# Remaining email work — handoff for extractmail planner / coder

**Audience:** Independent planner + coding agent pair on the **extractmail** host  
(`~/git/extractmail/`, multi-agent v2: orchestration / `master/` / `agent-N/`).  
**Not** the VehicleExpenses app worktree, except as a **consumer contract** and thin-caller backlog.  
**Date frozen:** 2026-08-05. Re-verify pins, HEADs, and goldens on load.

**Related (read-only orientation, may be stale on SHAs):**

| Doc | Where |
|-----|--------|
| This file | `sandbox/docs/remaining-email-work-handoff.md` (extractmail host) |
| VE first-party / email roadmap handoff | VE `dev-ai-interaction/plans/HANDOFF-first-party-libs-email-roadmap-20260802.md` |
| Fuel row + Wave 0 contract | VE `dev-ai-interaction/email-receipt/README.md` + `HANDOFF.md` |
| Product SoT milestones | extractmail `README.md`, `spec/OVERVIEW.md`, `spec/EXTERNAL.md` |
| Host TODO | extractmail `TODO.md` (master + orch) |
| Formalize plan (landed) | extractmail `sandbox/historical-plans/email-connection-m1-m3-formalize-20260803-plan.md` |

Plans for **new** work: write under **`~/git/extractmail/sandbox/plans/`** only  
(filename `descriptive-kebab-YYYYMMDD-HHMM-plan.md`). Do **not** use harness `plan.md` as the approved product plan.

---

## 1. Mission boundary (do not re-scope)

### extractmail owns

```text
message/HTML body  →  modular extract  →  JSON (+ _meta)  →  optional append-only write (remotetable)
```

Also: type registry / YAML configs, host CLI, external-tool contract, Apps Script **shared fixtures**,  
future browser **trainer**, packaging for host/router daemons, pure-Kotlin (or portable) extract for Android AAR.

### extractmail does **not** own

| Concern | Owner |
|---------|--------|
| Android UI (Settings “Email receipts”, sign-in buttons, offline ingest button) | VehicleExpenses |
| Google Sign-In / MSAL / EncryptedSharedPreferences for user OAuth in-app | VehicleExpenses |
| Room insert, WorkManager poll schedule, Gmail REST / IMAP **app** clients as product UX | VehicleExpenses (until thin wrappers only) |
| Multi-tab LWW spreadsheet **sync** engine, conflict UI | remotetable + VE |
| Odometer OCR, pump photo pipeline, vehicle assignment UX | VehicleExpenses |
| Inventing odometer / vehicle / Partial Fill=true on email fills | **Forbidden** (any layer) |

**Design rule:** Prefer improving extractmail contracts + goldens so VE becomes a **thin caller**.  
Avoid re-implementing Shell/Sam’s parsers only in the app without updating extractmail SoT.

---

## 2. What is already landed (do not rebuild)

Verify with commands at the end of this section.

### 2.1 Extract library (host)

| Piece | Location / notes |
|-------|------------------|
| Spec | `spec/OVERVIEW.md`, `spec/EXTERNAL.md` |
| Types | `shell-ereceipt`, `samsclub-fuel` (+ `auto` detect) |
| YAML packs | `extractors/*.yaml` (many fields still `strategy: reference_js`) |
| Reference JS | `extractors/reference-js/*` (ported from VE email-receipt) |
| Fixtures / goldens | `fixtures/*` + `python/run_goldens.py` |
| Stdin CLI | `scripts/extractmail`, `python/extractmail_stdin.py` |
| External contract | exit 0/1/2; tests in `run_external_contract.py` |
| Type registry | `python/type_registry.py` |
| Host IMAP fetch CLI | `python/fetch_mail.py` (token/password file; optional remotetable append) |
| Go wrapper | `scripts/extractmail-go` / `go/cmd` |
| Apps Script | `apps-script/` (zero-binary Gmail→Sheets; same fixtures) |
| AAR | `scripts/build-aar.sh` → `artifact/extractmail.aar` |

**AAR surface today (`Extractmail` object, VERSION 3):** type keys, detect heuristics, fuel contract constants, host CLI hints.  
**Not in AAR:** full HTML field extraction (no pure-Kotlin parse of Shell/Sam’s bodies yet).

### 2.2 VehicleExpenses consumption (context only)

In-app package (still product-critical, lives in **VE** git):

- `app/.../data/email/*` — Gmail + generic IMAP clients, WorkManager, Settings wiring  
- `ReceiptParsers` — **detect** via `Extractmail.detectType`; **parse** still `ShellReceiptParser` / `SamsClubReceiptParser` (Kotlin ports)  
- `FuelReceiptIngest` — Room rows using `Extractmail.FUEL_*` constants  
- Offline fixtures — golden JSON aligned with extractmail (no HTML re-parse on device for samples)

Pin (verify on resume): VE `third_party/extractmail/libpin.toml` / lock SHA — historically around `0dc3f80` on `master`; **do not trust this number without re-reading the pin file**.

### 2.3 Fuel intake contract (locked — never re-argue)

| Field | Value |
|-------|--------|
| Vehicle | system **Unassigned** / `vehicleId = 0` |
| Vehicle Sync ID | `a0000000-0000-4000-8000-000000000001` |
| Odometer | `0` |
| Partial Fill | **`false` only** |
| Economy Ignored | **`false`** |
| Cost | **fuel** amount paid **after discounts** |
| Volume | **fuel** gallons/liters only |
| Idempotency | Sync ID from message id (preferred) / stable fixture keys |
| Skip | no cost+volume+timestamp, wrong sender, non-fuel mess → skip (not invent) |

Goldens (host): Shell ≈ `144.77` / `32.036` and `52.34` / `13.12`; Sam’s ≈ `136.3` / `29.069` (confirm via `run_goldens.py`).

### 2.4 Quick verify (extractmail master or `src` worktree)

```bash
cd ~/git/extractmail/master   # or agent-N / third_party/extractmail/src
python3 python/run_goldens.py
scripts/extractmail --list-types
# optional if JDK 17 + Android SDK:
# scripts/build-aar.sh
```

Expect: all goldens PASS; external contract exits 0/1/2.

---

## 3. Remaining work — ordered for extractmail agents

Work below is **extractmail-repo primary**. Items marked **(VE later)** need a follow-on VE plan after lib ships; extractmail still defines contracts/artifacts.

### Priority A — Close the dual-parser gap (highest product value)

**Goal:** One SoT for HTML → fields so VE can delete or thin `ShellReceiptParser` / `SamsClubReceiptParser`.

| ID | Work | Notes |
|----|------|--------|
| **A1** | **Pure-Kotlin (or AAR-embedded) extract** for `shell-ereceipt` + `samsclub-fuel` matching host goldens | Device must not require Node. Prefer port of proven field logic + goldens in JVM tests under `android/` or shared fixtures. |
| **A2** | Keep host **Python/JS goldens bit-identical** to Kotlin | `run_goldens.py` remains gate; add Android unit tests on same `fixtures/expected-*.json`. |
| **A3** | YAML **xpath/css** paths for more fields (reduce `reference_js` dependency) | Partial `xpath_extract.py` exists; Shell YAML still largely `impl: reference-js`. |
| **A4** | Document **VE pin bump recipe** when AAR gains real parse API | Consumer: thin `ReceiptParsers.tryParse` → `Extractmail.parse(...)`; no behavior change to fuel contract. |

**Done when:** AAR can parse both vendors from HTML (+ headers for Sam’s date rules) to golden JSON without host Node; VE pin can switch live path (separate VE execute plan).

### Priority B — Browser trainer (human-confirm extract helper)

**Goal:** Anti-hallucination config builder — open sample email/HTML, user points at **visible** fields, download YAML.  
**Explicitly not:** auto-pick non-visible DOM / silent AI field invention.

| ID | Work | Notes |
|----|------|--------|
| **B1** | Scaffold `trainer/` static web app (GitHub Pages–friendly) | Load local file and/or remote sample URL; no secrets. |
| **B2** | User-directed field mapping UI → export YAML type pack | Align with `extractors/*.yaml` schema. |
| **B3** | Round-trip: exported YAML runs through host CLI / goldens harness | Optional: “diff against expected JSON”. |
| **B4** | (Optional later) Split trainer to its own repo if generally useful | `TODO.md` already notes this. |

Tracked as: extractmail `TODO.md` trainer bullet; VE backlog “browser-based human-confirm extract helper”.

### Priority C — Host fetch maturity (daemon / ops path)

`python/fetch_mail.py` is a start (IMAP + extract + optional remotetable append). Remaining:

| ID | Work | Notes |
|----|------|--------|
| **C1** | **Cursor persistence** | last Message-ID and/or IMAP `UIDVALIDITY`+UID only — not full mailbox index. |
| **C2** | **Dedup helpers** | skip if remote already has Sync ID and/or cost+volume+time; pure functions + tests. |
| **C3** | Gmail API fetch path (token file) if IMAP-via-Gmail is insufficient | Token file only; no interactive OAuth in headless default. |
| **C4** | Cron/systemd-friendly CLI flags + exit codes | Align with external contract style. |
| **C5** | Gmail-via-IMAP tweaks | Labels/folders; document app-password vs OAuth. |

**Out of scope for extractmail:** shipping Google Sign-In UI inside Android (VE).

### Priority D — Packaging & multi-arch host deploy

| ID | Work |
|----|------|
| **D1** | tgz / deb / rpm packaging |
| **D2** | OpenWrt (x86_64, aarch64 OpenWrt One, armv7l Turris Omnia classic) |
| **D3** | LuCI surface (later); PPA later |

Do **not** combine packaging with pure-Kotlin AAR cutover in one plan unless human demands it.

### Priority E — More extract types & expense-from-email (library side)

| ID | Work | Notes |
|----|------|--------|
| **E1** | Additional **fuel** loyalty brands (Chevron, etc.) | New YAML + fixtures + goldens; detect rules; no invent fields. |
| **E2** | **Expense receipt** email/HTML types (store total, vendor, date — not fuel contract) | Separate type keys; do not force `FUEL_*` constants. VE still owns expense Room/UI. |
| **E3** | Shared DTO docs for non-fuel JSON shape | Keep `_meta.fields` minimum. |

VE backlog still lists expense-from-email + “import fill/expense from email or file pickers” as **app** work once library types exist.

### Priority F — Apps Script parity & maintenance

| ID | Work |
|----|------|
| **F1** | Keep `apps-script/` parsers in lockstep with reference-js / goldens |
| **F2** | README setup for dry-run vs live sheet append (`Fuel - Unassigned`) |
| **F3** | Export path for offline goldens used by VE assets (`scripts/export_offline_goldens.sh`) |

Apps Script remains the **no-binary** Gmail→Sheets path; extractmail owns shared fixtures.

### Priority G — VE thin callers (**contracts first in extractmail**, code later in VE)

These are **not** primarily coded in extractmail, but extractmail plans should leave clean hooks:

| VE item | Extractmail enablement |
|---------|------------------------|
| Live Gmail/IMAP production hardening | Stable detect/parse API + error taxonomy (no match vs hard error) |
| Email **intent** / file picker import | Stdin/file extract API + documented MIME/HTML input |
| Preferred fuel grade / product on vehicle | Optional parsed `product` / `grade` field in JSON when present (do not invent) |
| Drop duplicate Kotlin parsers | **A1** complete + pin promote |

---

## 4. Suggested plan slices (planner guidance)

Prefer **small approved plans** over a mega-plan:

1. **`extractmail-pure-kotlin-shell-sams-goldens-…-plan.md`** — Priority A (AAR parse + goldens).  
2. **`extractmail-trainer-mvp-…-plan.md`** — Priority B (open file → map fields → YAML).  
3. **`extractmail-fetch-cursor-dedup-…-plan.md`** — Priority C.  
4. **`extractmail-packaging-…-plan.md`** — Priority D (after A/C stable).  
5. **New vendor / expense types** — only with real fixtures (no synthetic invent).

Each plan must:

- Cite `standard-plan-compliance-block.md` **by path only** (do not paste).  
- List verify commands (`run_goldens.py`, external contract, optional `build-aar.sh`).  
- State **VE pin promote** as out-of-scope or a separate VE plan.  
- Preserve fuel contract table in §2.3.

**Execute** only after human magic approval naming  
`sandbox/plans/<that-file>-plan.md` (extractmail multi-agent process).

---

## 5. Geography & process (extractmail host)

| What | Path |
|------|------|
| Orchestration / thin policy | `~/git/extractmail/` (branch `orchestration` typical) |
| Product master | `~/git/extractmail/master/` |
| Feature worktrees | `~/git/extractmail/agent-N/` |
| Sandbox (plans, PRs, research, **this doc**) | `~/git/extractmail/sandbox/` **absolute path preferred** |
| GitHub | `git@github.com:davidelang/extractmail.git` — agents **do not push** |
| remotetable (append-only write) | often pin under `third_party/remotetable` on lib host; product changes commit in **remotetable** git |
| VE pin consumer | VE `third_party/extractmail/` (`libpin.toml`, `artifact/extractmail.aar`) |

Process: read extractmail `AGENTS.md` → `AGENT_CONTEXT.md` → CLI overlay → `AGENT_MANDATES.md` → full `project-facts.md`.  
Eng-log only via `./append-to-engineering-log`. TODO via `./todo-append` / `./todo-close`.  
Policy freeze: `docs/LIBRARY_MULTI_AGENT_POLICY_FREEZE.md` if present.

**Three-repo awareness:** a full end-to-end email change may touch extractmail + remotetable + VehicleExpenses.  
For pure extract/trainer/daemon work, stay in **extractmail** only.

---

## 6. Explicit non-goals (until separate plans)

- Replacing VE Room / WorkManager with a second Android email stack inside extractmail.  
- Full spreadsheet merge/LWW in extractmail (that is remotetable + VE).  
- On-device Node/V8 for HTML parse.  
- Blind LLM auto-mapping of receipt fields without human-visible confirmation (trainer anti-goal).  
- Treating VE `dev-ai-interaction/subprojects/` or staging seeds as product SoT.  
- Inventing odometer, vehicle, or Partial Fill=true for loyalty fills.

---

## 7. Definition of “email extractmail done” (product north star)

From historical M3 roadmap language, condensed:

1. Shell + Sam’s extract reliable on **host** (goldens) and on **Android AAR** (same numbers).  
2. XPath/YAML configs loadable; external program contract stable.  
3. Apps Script no-install path still works on shared fixtures.  
4. Host CLI/cron/daemon can fetch → extract → optional remotetable append with cursor + dedup.  
5. VE Gmail/IMAP workers are **thin**: transport + OAuth + Room only; parse/detect from extractmail.  
6. Trainer exists for human-confirm new types without silent field invention.  
7. Packaging available for router/server installs (can lag 5–6).

Expense-from-email and multi-brand expansion are **extensions**, not blockers for (1)–(5).

---

## 8. One-screen summary for a new extractmail agent

> You work in **`~/git/extractmail`**, not VE app sources.  
> **Landed:** stdin extract, Shell+Sam’s goldens, CLI, external contract, IMAP fetch CLI, Apps Script, AAR **detect + fuel constants** (not full on-device parse).  
> **Next high-value:** pure-Kotlin/AAR parse matching goldens → then browser **trainer** → then cursor/dedup/daemon polish → packaging.  
> **Fuel contract:** Unassigned / odo 0 / Partial Fill false / fuel-only cost+vol / message-id Sync ID.  
> **VE** keeps OAuth, Settings, WorkManager, Room; becomes thinner as AAR grows.  
> Plans only under **`sandbox/plans/`**; verify with **`python3 python/run_goldens.py`**.

---

## 9. Changelog of this handoff

| Date | Note |
|------|------|
| 2026-08-05 | Initial write for independent extractmail planner/coder pair; based on master goldens PASS, AAR v3 surface, VE dual-parser state, extractmail `TODO.md`, M1–M3 formalize historical plan, VE email HANDOFF/README. |

*When A1 or B1 lands, update §2 and this table (or supersede with a dated copy under `sandbox/docs/`).*
