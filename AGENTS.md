# AGENTS.md — Library multi-agent bootstrap

Entry point for agent CLIs on **this** library repository (not VehicleExpenses app).

## Immediate reads (session start / after compact / new cycle)

**Role pack** (full read — not every message):

1. `./AGENT_CONTEXT.md`
2. CLI overlay: `./GROK.md` or `./GEMINI.md`
3. `./AGENT_MANDATES.md`
4. `./project-facts.md` (**full**)
5. **If Master:** `MASTER_AGENT_MANDATE.md`
6. **If Planner:** `standard-plan-compliance-block.md` (path), `sandbox/research/plan-style-guide.md`, designated plan if any
7. **If Coder (execute):** `standard-plan-compliance-block.md` + **approved** plan path only
8. **Master / orch after handoff:** `MULTI_AGENT_USER_INSTRUCTIONS.md`
9. Confirm **`pwd` once** — never `cd … && ./helper`

When **spawning**, load full `.grok/prompts/*` files. Launchers compose via `.grok/prompts/compose-session-prompt.sh`.

## Launchers (role → command)

| Launcher | OS user (typical) | Role | Plans? | Implements? | Native plan mode? |
|----------|-------------------|------|--------|-------------|-------------------|
| `./run-grok-orchestrator` | ai-orchestrator | Meta / brain | Meta | Meta | Optional |
| `./run-grok-master` | ai-coder | Execute dispatch; local PR merge | No | Via coder | No |
| `./run-grok-planner` | ai-planner | Planning; **owns new cycles** | Yes | **No** | **Avoid** |
| `./run-grok-coder` | ai-coder | Implement in agent-N | **No** | Yes (approved plan) | **No** |
| `./run-grok` | dlang | Bare session | Yes | Yes | Optional |

Agents **do not `git push`**. Human publishes to GitHub.

## Skills

Prefer project multi-agent path. Do not use bundled `design` / `execute-plan` / `implement` / `pr-babysit` as default. Local PR: `sandbox/PRs/` + master review (day-1 ritual).

## Key files

| File | Purpose |
|------|---------|
| AGENT_CONTEXT.md | Role/branch/geography |
| AGENT_MANDATES.md | Shared core law |
| standard-plan-compliance-block.md | Execution gates — **cite; do not paste** |
| project-facts.md | Orientation |
| TODO.md | Future (`todo-append` / `todo-close`) |
| ENGINEERING_LOG.md | `./append-to-engineering-log` only |
| MULTI_AGENT_USER_INSTRUCTIONS.md | Human magic phrases |
| MASTER_AGENT_MANDATE.md | Master merge/execute |
| sandbox/ | Plans, research, failure logs, PRs |

## Plans

- Designated: `sandbox/plans/<kebab>-YYYYMMDD-HHMM-plan.md`
- Completed → `sandbox/historical-plans/`
- Research findings default to **chat**

## Lifecycle tags

- **builds** — initial smoke (compile + tests in verify)
- **deployed** — sent for additional testing
- **works** — full regression; **user only**

## Worktree / rules sync

Tracked policy copies: commit on that worktree or `./update-rules.sh` from orchestration. Uncommitted tracked dirt must not be ignored when verifying.

## Next steps after reading

- Fresh launch: Mandate Acknowledgment from `new_agent_prompt`, then STOP & WAIT.
- Implementation only after magic approval naming `sandbox/plans/<name>-plan.md`.
- Planning = research + plan file only.

Report role, branch, and mandates understanding now.
