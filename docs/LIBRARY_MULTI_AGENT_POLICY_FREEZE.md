# Library multi-agent policy freeze (remotetable / extractmail)

**Date:** 2026-08-02  
**Method:** copy-adapt from VehicleExpenses (not a shared monorepo package)  
**Applies to:** `~/git/remotetable`, `~/git/extractmail` (orchestration + master + agent-N)

This freezes human decisions for bootstrap v2. Product languages and the eventual `./verify` / build entrypoints are **project code**; process law is here.

---

## Lifecycle tags (language-agnostic)

| Tag | Meaning | Who sets |
|-----|---------|----------|
| **`builds`** (branch-prefixed except on `master`) | Passed **initial smoke**: compile/typecheck (or equivalent) **and** the automated tests run as part of the post-edit verify for that phase | Agent via project verify/tag helper (VE analogue of `build_app`) |
| **`deployed`** | Sent for **additional testing** (human/CI extended suite, staging, consumer pin trial — **not** Android-only) | Agent only when the plan/user asks to mark “ready for extra testing”; not every `builds` |
| **`works`** | **Full regression** passed | **User only** — agents never set/move `works` |

Not every green smoke gets `deployed`. Trivial intermediate checks may only need `builds` (or even phase-local verify without promoting tags — follow plan).

Convention: branch-scoped tags (`feature/foo/builds`) except on `master` (`builds`).

---

## Baseball (recovery)

**Intent:** small mistakes get limited retries; thrashing is forbidden.

- **Strike** = post-edit verify failed (compile/typecheck failure **or** test failure — both count).  
- **3 strikes = 1 out** → reset to last good phase / last good `builds` tag (via tag helper preflight; three git-reset contexts only).  
- **3 outs = end of inning** → write `sandbox/implementation-failure-logs/<date>-<slug>-inning-end.md`, deeper analysis, **replan** (often smaller steps). Do not keep hammering the same approach.  
- Egregious failure may be an immediate out.

Plain language: try to implement something; you get two fix attempts after failures before backing up; after three failed implementation attempts (with fixes), stop thrashing, analyze, replan, restart.

---

## Verify / “build_app equivalent”

- Language-specific; developed **in that repo** (`go test`, `pytest`, gradle AAR, multi-step `./verify`, etc.).  
- Until a helper exists, plans name the exact commands; STANDARD BLOCK still requires **successful verify before next phase**.  
- Compile failure before tests = strike. Test failure = strike.

---

## Agent git remotes

- Agents work **locally** only for now.  
- **No `git push`** (and no force-push) by agents.  
- Human pushes to GitHub when ready.  
- Ban amend; ban relative resets (`HEAD~`, etc.) — same as VE.

---

## Deploy / Android

- VE “no agent deploy / adb / installDebug” is **Android device-env** policy — **not** library foundational law.  
- adb/logcat: **out**.  
- ICRS/coordinates: **out** (not relevant).  
- Library “deployed” tag = extra testing handoff, not `adb install`.

---

## Process parity with VE (day 1)

- Full planner / coder / master / orch roles  
- Magic path approval; bi-modal; completeness; END marker; new cycle  
- Local PR markdown under `sandbox/PRs/` + master review before merge to lib `master`  
- Eng-log wrapper + `chattr +a` + setgid/sudo pattern like VE  
- todo-append / todo-close  
- Merge drivers for ENGINEERING_LOG / TODO / project-facts  
- TodoGate and related processes: **same as VE** where applicable  
- No auto `update-rules` mid-execute unless human requests  
- getopt_long / long options for new CLIs  
- Copy-adapt packs (drift OK; no forced shared package)

---

## Install

Templates live under VE orchestration:

`bootstrap-lib-multiagent-v2.d/`

Human runs (when ready):

`./bootstrap-lib-multiagent-v2.sh`

Installs into both library hosts, commits on orchestration + syncs to master worktrees via update-rules-style copy, runs `install-merge-drivers.sh`, applies `chattr +a` on eng-logs (may need sudo).

---

## Launchers (2026-08-02 addendum)

`run-grok*` scripts are **identical across projects**. They contain **no agent law**.

- Compose only files listed in `.grok/prompts/packs/<role>.pack`
- Wiring via `project.config` (`sandbox_dir`, OS users, optional models)
- Per-project rules only in `AGENT_MANDATES.md`, `new_agent_prompt`, `.grok/prompts/role-*.md`, etc.

See `docs/LAUNCHERS.md` in this pack.
