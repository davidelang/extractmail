#!/usr/bin/env bash
# update-rules.sh — library host: sync policy/tools from orchestration root into worktrees.
# Usage: from orchestration root: ./update-rules.sh [--dry-run]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1

FILES=(
  AGENT_MANDATES.md AGENTS.md GROK.md new_agent_prompt standard-plan-compliance-block.md
  MASTER_AGENT_MANDATE.md MULTI_AGENT_USER_INSTRUCTIONS.md project-facts.md
  append-to-engineering-log todo-append todo-close get-builds-tag.sh install-merge-drivers.sh
  .gitattributes run-grok run-grok-planner run-grok-coder run-grok-master run-grok-orchestrator
  filter-apply-config filter-clean-config
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
}

# master worktree + any non-git special dirs that look like worktrees
sync_one "$ROOT/master"
for d in "$ROOT"/*/; do
  base="$(basename "$d")"
  [[ "$base" == "master" || "$base" == "sandbox" || "$base" == ".git" ]] && continue
  if [[ -f "$d/.git" || -d "$d/.git" ]]; then
    sync_one "${d%/}"
  fi
done

if [[ "$DRY" -eq 0 ]]; then
  echo "Done. Commit on each worktree if you need policy changes tracked there."
fi
