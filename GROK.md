# Grok Project Mandates (Overlay) — library host

Thin overlay. Shared law: `AGENT_MANDATES.md`.

**Grok CLI:**

- Tools: Read, Write, StrReplace, Shell, Task/spawn, enter/exit plan mode.
- **Shell cwd:** `pwd` once at startup. Invoke `./append-to-engineering-log`, `./todo-append`, `./todo-close`, `./get-builds-tag.sh`, project verify helpers as literal `./helper` — **never** `cd … &&`.
- **Native plan mode:** Optional only for bare `./run-grok` and orchestrator. **Planner and coder must not rely on it.** Approved work plan is always `sandbox/plans/…-plan.md`; harness `plan.md` is process log only.
- **Planning:** Research + revise sandbox plan only. Do not call `exit_plan_mode` until user path-approves. “Helpful” ≠ implement or verify-as-impl.
- **Execution:** Only after magic approval of exact plan path. Completeness pass before handoff. Plan Status APPROVED → CODE LANDED.
- **Spawn prompts:** Load full `.grok/prompts/planning-subagent.md` / `execution-subagent.md` / `dedicated-planner.md` when spawning.
- **Git:** Three reset contexts + tag preflight. **No agent push** to GitHub.
- **Tags:** `builds` = smoke; `deployed` = extra testing handoff; `works` = user-only full regression.
- Worktree policy deploy: no uncommitted tracked dirt after `cp` (use `update-rules` or commit).

**Re-read after compaction:** role pack in `AGENTS.md` (not every turn).

**CLIs:** new tools use long options (`getopt_long` or equivalent).
