# project-facts.md — extractmail

Cold-start orientation. Prune; no plan/branch status novels.

## Host layout

- Orchestration: `~/git/extractmail/` (branch `orchestration`)
- Product: `~/git/extractmail/master/` (branch `master`)
- Features: `~/git/extractmail/agent-N/`
- **Sandbox (absolute):** `@@ORCH_ROOT@@/@@SANDBOX_PATH@@/` — plans, research, failure logs, PRs (use this when cwd is master/agent-N)

## GitHub

- `git@github.com:davidelang/extractmail.git` (public, MIT)
- Agents **do not push**; human publishes

## Helpers (must exist after multi-agent v2 bootstrap)

- `./append-to-engineering-log` — only way to append ENGINEERING_LOG.md
- `./todo-append` / `./todo-close`
- `./install-merge-drivers.sh` — eng-log / TODO / project-facts merge drivers
- `./update-rules.sh` — sync policy from orchestration into worktrees
- `./setup_agent.sh` / `./remove_worktree.sh` — feature worktrees
- `./get-builds-tag.sh` — builds tag preflight for baseball reset
- `./run-grok-*` — role launchers
- Project **verify** entrypoint: document here when implemented (language-specific)

## Lifecycle tags

- `builds` — initial smoke (compile + tests in verify)
- `deployed` — additional testing handoff
- `works` — full regression; user only

## Consumers

Equal consumers (e.g. VehicleExpenses, extractmail) **pull** pins. See VE `docs/reference/FIRST_PARTY_LIBS.md` for consumer contract.

## Policy freeze

Process law: `docs/LIBRARY_MULTI_AGENT_POLICY_FREEZE.md` if present, else VE orchestration `bootstrap-lib-multiagent-v2.d/docs/LIBRARY_MULTI_AGENT_POLICY_FREEZE.md`.

## Review after implement
- Record HEAD before the executor starts. Each phase: `git diff` that phase's paths against that phase's observable, then commit and build green before the next phase. Before handoff, re-read the plan once.
- A plan line `Review: diff` starts one reviewer. Prompt is the plan path and `<recorded>..HEAD`. Diff that range only. Check the plan's Critical Files and Acceptance lines. Reply in chat. Do not diff `master..<branch>`.
- A deletion, a doc edit, or a pin bump omits `Review: diff`.
- A reviewer `STATUS: FAIL` names a bug: the executor fixes that bug, then the reviewer runs again on the new range.
