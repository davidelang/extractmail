# Agent Mandates (library host — slim)

Adapted from VehicleExpenses multi-agent core for **extractmail**.

## Write authority

- **Planning:** sandbox `./sandbox/` only (+ TODO/eng-log wrappers if present). No product implementation until approved plan under `sandbox/plans/`.
- **Execution:** only after magic approval of exact `sandbox/plans/…-plan.md`.

## Bi-modal

Planning ≠ implementation. Handoff ends the turn; feedback = new planning cycle.

## Geography

- Confirm `pwd` once; never `cd … && ./helper`.
- Never use `..` path hacks to escape the worktree for “convenience.”
- Worktrees: orchestration root, `./master/`, `./agent-N/`.

## Special files

- `TODO.md` via wrappers only when provided.
- `ENGINEERING_LOG.md` via `./append-to-engineering-log` only when provided.
- Plans: `sandbox/plans/<kebab>-YYYYMMDD-HHMM-plan.md`.

## Verification

- After product edits: tests appropriate to this repo (unit/conformance). **No** `./deploy` / adb install from agents.
- No VehicleExpenses `./build_app` requirement unless you are in a VE worktree.

## Independence

Commits here do **not** require a VehicleExpenses commit. Consumers pull pins when they need updates.

## CLI tools

New command-line tools: **long options** (`getopt_long` or equivalent), not ad-hoc flag parsing.
