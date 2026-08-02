# Agent Mandates (Shared Core — library host)

Authoritative shared core for multi-agent work on **this** repository (remotetable or extractmail).  
Copy-adapted from VehicleExpenses; Android device rules intentionally omitted.

Overlays (`GROK.md`, `GEMINI.md`) map tools. Spawn prompts: `.grok/prompts/planning-subagent.md`, `execution-subagent.md`, `dedicated-planner.md`.

Human rituals: `MULTI_AGENT_USER_INSTRUCTIONS.md`. Execution gates: `standard-plan-compliance-block.md` (**cite by path; never paste**).

---

## 1. Precedence and foundational bans

Overlays + this file take absolute precedence. Bypassing protocol for speed is a **High-Severity Performance Failure**.

- An **approved plan never** authorizes foundational violations (`git commit --amend`; moving/rewriting lifecycle tags outside rules; **agent `git push`** / force-push to remotes).
- **Agents do not push to GitHub.** Local commits only; human publishes.
- Lifecycle tags are **branch-prefixed** except on `master`:
  - **`builds`:** initial smoke passed (compile/typecheck equivalent **and** automated tests included in that verify). Set via project verify/tag helper when used.
  - **`deployed`:** handed off for **additional** testing (not every `builds`). Not Android-specific.
  - **`works`:** full regression passed — **user only**. Agents never set or move `works`.
- Version integrity: commit before verifies that matter for `git describe`. Prefer multi-line phase summaries via helper/`@file` when available.
- Language/stack: follow **this** repo’s tools and docs; do not assume Android/Gradle or default web-stack advice.

---

## 2. Write authority

### 2.1 Planning (until magic approval of a named sandbox plan)

**May write:** sandbox  
`./sandbox/` (absolute: host `…/sandbox/` — same for all worktrees; prefer absolute if cwd is `master/` or `agent-N/`)  
plus:

- `project-facts.md` (orientation only — §7)
- `TODO.md` **only** via `./todo-append` / `./todo-close`

**Must not:** edit other tracked product files; run product verify as “implementation”; implement library source.

**Helpfulness in planning** = research, alternatives, better plan document — **not** source changes or “just one fix.”

### 2.2 Execution (after user magic-approves exact `sandbox/plans/…-plan.md`)

Only that plan’s observable contract. **First action:** `./append-to-engineering-log`. Re-read `standard-plan-compliance-block.md` at execute start (cite in plans; never paste).

### 2.3 Pure research

Explain/where/how with no change intent: answer in **chat**. No formal plan until user steers toward non-sandbox tracked edits.

### 2.4 Research communication

Default: findings in **chat**. Files only if asked or durable cache — still **state issues in chat**.

---

## 3. Bi-modal boundary

| Mode | May | Must not |
|------|-----|----------|
| **Planning** | Research; sandbox plans; allowed special-file edits | Product source; implementation verifies; vague “go ahead” as approval |
| **Execution** | Edits per approved plan only | Scope creep; post-handoff feedback as same turn |

**Approval:** Explicit user phrase naming the **exact** sandbox plan path. Vague approval is insufficient.

### 3.1 Mid-execution product feedback

User says wrong behavior / still broken mid-execute → plan was imprecise. Finish only true in-contract completeness gaps, or stop for **new plan**. No invented scope from chat corrections.

### 3.2 Handoff ends the turn

After plan-scope complete, forensics, successful **verify** (project’s post-edit check), and exact END marker from STANDARD BLOCK + ready-to-test, the turn is **over**. Further feedback = **new planning cycle**.

### 3.3 Letter and spirit (forbidden rationalizations)

Same as VE: no “not forbidden,” “one more edit,” harness `plan.md` as approval, allow-list dodges, etc.

**Shell:** literal `./helper` at command start. **Never** `cd … && ./helper`. `pwd` once at startup; keep cwd at **this worktree** root.

### 3.4 Subagents

**Blocked during planning.** When spawning in allowed contexts, load the **full** prompt file — do not weaken it.

### 3.5 Native plan mode

Planner/coder **avoid**. Bare `run-grok` / orchestrator optional. Real approval = path-named magic phrase.

### 3.6 Skills

Project config + `AGENTS.md` control skills. Do not treat bundled design/execute-plan/implement/pr-babysit as the default multi-agent path.

### 3.7 Long-lived handoff / new cycle

Follow `MULTI_AGENT_USER_INSTRUCTIONS.md` (post-handoff gate file under `sandbox/` when staying in long chat). Planner owns new cycles.

---

## 4. Execution quality

- **Before any edit:** re-read target file; do not trust prior-turn memory.
- Write-tool success ≠ integrity. After edits: forensic read/grep; **verify** per phase (STANDARD BLOCK).
- **Verify** = whatever this repo uses after editing source to know it can work: compile/typecheck failure **and** test failure both count as failures (strikes).
- **Plan completeness (mandatory)** before ready-to-test. Blocked → report, no ready-to-test.
- Plan Status: **APPROVED** → **CODE LANDED** or **BLOCKED — needs replan**.
- Product-intent PASS is not coder’s claim. Master Compliance Checker **optional**.
- Total turn reversion only during **active** execution before handoff (approved reset §6). After handoff, feedback = new cycle.

**END marker** (exact):  
`**END OF EXECUTION TURN. Awaiting new directive or plan approval before any further source changes or investigation that leads to edits.**`  
then `results ready to test (new tag: ...)` when a tag was created.

---

## 5. Baseball and recovery

**Intent:** small errors get limited retries; do not thrash.

- **Strike** = failed verify this phase (build/compile/typecheck **or** tests).
- **3 strikes = out** → reset to last good phase / last good builds tag (`./get-builds-tag.sh` preflight when present).
- **3 outs = end of inning** →  
  `sandbox/implementation-failure-logs/<date>-<slug>-inning-end.md`  
  deeper analysis, **replan** (commonly smaller steps), restart.  
- Default ~3–8 coherent phases; finer only post–inning-end. Egregious failure = immediate out.
- Recovery plans include **Already completed (exclude)**.

Plain language: after a failed implementation you get fix attempts within the strike budget; after three outs, stop and replan rather than repeating the same failing approach.

---

## 6. Git reset (three contexts only)

**Preflight:** `TAG=$(./get-builds-tag.sh)` when the helper exists; then verify/reset. No relative-ref games.

1. **Uncommitted junk:** `git checkout .` / `git restore .` / `git reset --hard HEAD`
2. **Build/baseball recovery:** `git reset --hard builds` (master) or `git reset --hard <current-branch>/builds` only
3. **Forbidden:** any relative ref (`HEAD^`, `HEAD~`, …); arbitrary hashes unless user supplies; `origin/*`; other agents’ tags; **agent push/force-push**

---

## 7. Geography and special files

- **Never** `..` to escape the worktree for convenience.
- Sandbox: `sandbox/` (plans, research, failure logs, PRs, gates). Prefer absolute host path from `project-facts.md` when cwd is not orchestration root.
- Orchestration root is source for `./update-rules.sh`. Tracked copies into other worktrees must be committed or applied via update-rules.
- **Plans:** user-designated under `sandbox/plans/` only. Completed → `sandbox/historical-plans/`. Never harness session `plan.md` as approved work plan.
- **Filenames:** `descriptive-kebab-YYYYMMDD-HHMM-plan.md`.
- **Plan content:** Context, Approach, Critical Files, reuse, **Phased Execution**, Verification/Acceptance. Cite STANDARD BLOCK by path only. Soft ~2–8 KB. Style: `sandbox/research/plan-style-guide.md`.
- **project-facts:** orientation only; full read on launch/new cycle/before major edit.
- **TODO:** future only; `./todo-append` / `./todo-close` only.
- **ENGINEERING_LOG:** `./append-to-engineering-log` only (append-only file; do not rewrite history of the log by hand).

---

## 8. Logs and diagnostics

- Prefer project log files / test output into sandbox once; analyze locally.
- **No adb/logcat** requirements (not applicable).

---

## 9. Engineering defaults

- Prefer `jq` for JSON when relevant.
- **New CLIs:** long options (`getopt_long` or language equivalent) — structured flags, not ad-hoc parsing only.
- Language-specific build/test entrypoints live in-repo; document in `project-facts.md` when stable.
- Consumer pins (VehicleExpenses, etc.) are **pull** model — this repo does not push into consumers.

---

## 10. Re-read policy

Mandatory role pack at: session start; after compact; new planning cycle; execution start for a new approved plan.

| Everyone | + Planner | + Coder | + Master / orch after handoff |
|----------|-----------|---------|--------------------------------|
| `AGENT_CONTEXT.md`, overlay, this file, full `project-facts.md` | STANDARD BLOCK path, plan-style-guide, designated plan, spawn prompts when spawning | STANDARD BLOCK, **approved plan**, execution prompt when spawning | `MASTER_AGENT_MANDATE.md`; **`MULTI_AGENT_USER_INSTRUCTIONS.md`** |

Not every message.

---

## 11. Roles

| Role | Plans | Implements product |
|------|-------|--------------------|
| Planner | Yes | No |
| Coder | No | Yes (approved plan only) |
| Master | No | Coordinate / merge / dispatch execute |
| Orchestrator / bare run-grok | Meta | Meta; optional native plan mode |

Planner owns new cycles. Failure logs under `sandbox/implementation-failure-logs/`.

---

## 12. Human / launcher detail

Magic phrases and two-terminal ritual: `MULTI_AGENT_USER_INSTRUCTIONS.md`. Launchers compose files under `.grok/prompts/` — do not re-author conflicting law in shell strings.
