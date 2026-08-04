#!/usr/bin/env bash
# update-rules.sh — library host: sync policy/tools from orchestration root into worktrees.
# Usage: from orchestration root: ./update-rules.sh [--dry-run]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1

FILES=(
  AGENT_MANDATES.md AGENTS.md GROK.md GEMINI.md new_agent_prompt standard-plan-compliance-block.md
  MASTER_AGENT_MANDATE.md MULTI_AGENT_USER_INSTRUCTIONS.md project-facts.md
  append-to-engineering-log todo-append todo-close get-builds-tag.sh install-merge-drivers.sh
  .gitattributes run-grok run-grok-planner run-grok-coder run-grok-master run-grok-orchestrator
  filter-apply-config filter-clean-config
  setup_agent.sh remove_worktree.sh update-rules.sh
  project.config.example merge-branch-into-master.sh checkifclean
  setup-project
  landlock.config
  landlock.config.example
  run-antigravity
  run-antigravity-master
  run-antigravity-planner
)

sync_one() {
  local dest="$1"
  [[ -d "$dest" ]] || return 0
  echo "sync → $dest"
  for f in "${FILES[@]}"; do
    [[ -e "$ROOT/$f" ]] || continue
    if [[ "$DRY" -eq 1 ]]; then
      echo "  would copy $f"
    else
      cp -a "$ROOT/$f" "$dest/"
    fi
  done
  if [[ -d "$ROOT/.grok" ]]; then
    if [[ "$DRY" -eq 1 ]]; then echo "  would sync .grok/"; else
      mkdir -p "$dest/.grok"
      cp -a "$ROOT/.grok/." "$dest/.grok/"
    fi
  fi
  if [[ -d "$ROOT/git-merge-drivers" ]]; then
    if [[ "$DRY" -eq 1 ]]; then echo "  would sync git-merge-drivers/"; else
      mkdir -p "$dest/git-merge-drivers"
      cp -a "$ROOT/git-merge-drivers/." "$dest/git-merge-drivers/"
    fi
  fi
  # project.config is local-only: seed from example if missing
  if [[ ! -f "$dest/project.config" && -f "$ROOT/project.config.example" ]]; then
    if [[ "$DRY" -eq 1 ]]; then echo "  would seed project.config from example"
    else cp -a "$ROOT/project.config.example" "$dest/project.config"; fi
  elif [[ ! -f "$dest/project.config" && -f "$ROOT/project.config" ]]; then
    if [[ "$DRY" -eq 1 ]]; then echo "  would copy local project.config"
    else cp -a "$ROOT/project.config" "$dest/project.config"; fi
  fi
}

sync_one "$ROOT/master"
for d in "$ROOT"/*/; do
  base="$(basename "$d")"
  [[ "$base" == "master" || "$base" == "sandbox" || "$base" == ".git" || "$base" == "third_party" ]] && continue
  if [[ -f "$d/.git" || -d "$d/.git" ]]; then
    sync_one "${d%/}"
  fi
done

if [[ "$DRY" -eq 0 ]]; then
  echo "Done. Commit on worktrees only if those branches should track the file versions."
fi
