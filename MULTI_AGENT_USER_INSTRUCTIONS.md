# MULTI_AGENT_USER_INSTRUCTIONS (library host — slim)

Human rituals for multi-agent work on this library repo. Full spirit matches VehicleExpenses; paths use **`sandbox/`**.

## Two-terminal mode

- Master: `./run-grok-master`
- Planner: `./run-grok-planner`

**New planning cycle:** say `New planning cycle` (optional one-liner) in **master**. Master writes `sandbox/.planning-agent-prompt.txt`; you restart planner. Give the problem statement in the planner terminal.

## Approval (required for implementation)

Must name the exact plan path, e.g.:

- `approved the plan at sandbox/plans/<exact>-plan.md for the following request: …`
- `The user approved the plan at sandbox/plans/….md. Proceed with execution of exactly the steps described in that plan only.`

Vague “go ahead” / “looks good” is **not** enough.

## After handoff

After END marker + ready-to-test + successful verify: turn is **over**. Next feedback = new planning cycle (relaunch or gate file under `sandbox/.post-handoff-gate.txt`).

## Baseball (reminder)

3 strikes (failed verify: compile **or** tests) = out → reset last good phase/tag.  
3 outs = end of inning → failure log + replan (smaller steps).  
See `AGENT_MANDATES.md` §5.

## Tags

- **builds** — initial smoke  
- **deployed** — sent for additional testing  
- **works** — full regression; **you only**

## Remotes

Agents commit **locally**. **You** `git push` when ready. Agents must not push.

## Never-say (after handoff)

Avoid treating “one small fix” as same execution turn without a new approved plan path.

## Local PR

Before merge to `master`: `sandbox/PRs/PR-<branch>.md` + master review (day-1 process).
