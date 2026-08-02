## COMPLIANCE & EXECUTION GUARDRAILS (STANDARD BLOCK — library host; DO NOT PASTE INTO PLANS)

Plans must **cite this file by path** (one line). Do **not** paste this block into plan documents.

- **Scope:** Implement only observable changes in the plan's **Phased Execution** / product locks. No scope creep.

- **Per-phase gates** (details: `AGENT_MANDATES.md`):
  - **Start:** Re-read approved plan + `project-facts.md` (full); first action `./append-to-engineering-log` (never ritual TODO). Set plan **Status: APPROVED**. **No `cd … &&` on helpers** — cwd fixed after startup.
  - **Each phase:** Phase-only edits → forensic read/grep → `git add` (sources + `ENGINEERING_LOG.md` if appended) → **successful verify** before the next phase.
    - **Verify** = this repo’s post-edit check (language-specific): compile/typecheck failure **or** test failure both fail the phase (baseball **strike**).
    - Use project helper when present (e.g. `./verify`, `./build_app` analogue); until then, run the exact commands named in the plan and treat failure as a strike.
  - **Completeness (before handoff):** Re-read plan contract. Missing/reverted in-scope work → implement it. If blocked → **Status: BLOCKED — needs replan**, report gaps, do **not** ready-to-test.
  - **Granularity:** Coherent independently verifiable phases (~3–8 typical). Finer only after end of inning (3 outs) via End of Inning Report.
  - **Recovery:** Reset only via `./get-builds-tag.sh` preflight when available (three git-reset contexts). **3rd out:** inning-end report under `sandbox/implementation-failure-logs/` before replan.

- **Hygiene:** `project-facts.md` = orientation only; `TODO.md` future-only via `todo-append`/`todo-close`; `ENGINEERING_LOG` via `./append-to-engineering-log` only; sandbox `./sandbox/` (absolute path in project-facts).

- **Remotes:** Agents do **not** `git push`. Human publishes.

- **Handoff:** After completeness + final verify + verification, set plan **Status: CODE LANDED**, emit exactly:  
  `**END OF EXECUTION TURN. Awaiting new directive or plan approval before any further source changes or investigation that leads to edits.**`  
  then `results ready to test (new tag: ...)` when applicable.  
  Product-intent chat is human/planner; master Compliance Checker is **optional**.

- **Standing rules:** `AGENT_MANDATES.md`, `MULTI_AGENT_USER_INSTRUCTIONS.md`, role pack in `AGENTS.md` (re-read on launch, compaction, new cycle — not every turn).
