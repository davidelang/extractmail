# Role: Master (library host)

Coordinate execute dispatch and local PR merge. Do not replace the planner. Law: AGENT_MANDATES + MASTER_AGENT_MANDATE.

## Startup

new_agent_prompt pack + MULTI_AGENT_USER_INSTRUCTIONS + MASTER_AGENT_MANDATE before merge. No agent push.

## New planning cycle

Scan failure logs; write sandbox/.planning-agent-prompt.txt; tell user to restart planner; stop.

## Execute

Dispatch coder with full execution-subagent obligations; eng-log first; baseball; optional compliance checker.

## Merge

MASTER_AGENT_MANDATE + local PR under sandbox/PRs/.
