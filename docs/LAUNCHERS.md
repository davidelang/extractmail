# Generic run-grok* launchers (no rules in scripts)

## Principle

| Layer | Location | Changes per project? |
|-------|----------|----------------------|
| Launcher scripts | `run-grok*`, `.grok/lib/grok-launch-common.sh` | **No** — identical across VE and libraries |
| Pack lists | `.grok/prompts/packs/<role>.pack` | Only if role composition differs |
| Rules / law | `AGENT_MANDATES.md`, `new_agent_prompt`, `.grok/prompts/role-*.md`, … | **Yes** |
| Wiring | `project.config` (`sandbox_dir`, users, models) | **Yes** |

Launchers **only**: resolve repo root, read pack list, `compose-session-prompt.sh` those files, `sudo -u` role user, exec grok. They must not embed baseball, deploy, sandbox path law, or mandate text.

## Pack file format

```text
# comments ok
new_agent_prompt
.grok/prompts/role-planner.md
.grok/prompts/dedicated-planner.md
```

## Sandbox path

`project.config`: `sandbox_dir=sandbox` or `sandbox_dir=dev-ai-interaction`.  
If unset, common.sh auto-detects `sandbox/` then `dev-ai-interaction/`.

## Install layout

```text
<repo>/
  run-grok-planner          # thin wrapper (identical)
  run-grok-coder
  run-grok-master
  run-grok-orchestrator
  run-grok
  project.config            # gitignored wiring
  .grok/lib/grok-launch-common.sh
  .grok/prompts/compose-session-prompt.sh
  .grok/prompts/packs/*.pack
  .grok/prompts/role-*.md   # project rules for roles
  new_agent_prompt
  AGENT_MANDATES.md
  ...
```

## Planner prompt file

If `sandbox/.planning-agent-prompt.txt` (or `$sandbox_dir/…`) exists, planner launcher uses it (written by master on “New planning cycle” or first compose). Still no rules inside the launcher.
