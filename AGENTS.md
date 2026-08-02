# AGENTS.md — extractmail multi-agent host

- **Repo:** extractmail (`git@github.com:davidelang/extractmail.git`)
- **Roles:** planner / coder / orchestrator (same OS users as VehicleExpenses when co-hosted)
- **Branches:** `orchestration` (this tree root) · `master` (product worktree `./master/`) · `agent-N` feature worktrees
- **Sandbox:** `./sandbox/` (not `dev-ai-interaction`)
- **Product code:** primarily on `master` / feature branches — not only orchestration
- **Consumers:** VehicleExpenses and extractmail are **equal**; this repo does not push into them
- **Mandates:** `AGENT_MANDATES.md` (library-adapted; no Android deploy; tests = project test entrypoint)
- **VehicleExpenses policy cross-link:** VE `docs/reference/FIRST_PARTY_LIBS.md` after VE bootstrap commit

Startup: read `AGENT_CONTEXT.md`, overlay, `AGENT_MANDATES.md`, `project-facts.md` if present. Confirm `pwd` once.
