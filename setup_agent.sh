#!/usr/bin/env bash
# setup_agent.sh — library host (remotetable/extractmail).
# Usage (from library orchestration root): ./setup_agent.sh <branch-name>
set -euo pipefail

BRANCH_NAME="${1:-}"
if [[ -z "$BRANCH_NAME" ]]; then
  echo "Usage: $0 branch-name" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [[ ! -d .git && ! -f .git ]]; then
  echo "Error: run from library repo root (orchestration worktree)" >&2
  exit 1
fi

export LIB_SETUP_AGENT=1
export VE_SETUP_AGENT=1

WT_DIR="$ROOT/$BRANCH_NAME"
if [[ -d "$WT_DIR" ]]; then
  echo "Worktree already exists: $WT_DIR"
  exit 0
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  git worktree add "$WT_DIR" "$BRANCH_NAME"
else
  BASE=master
  git show-ref --verify --quiet refs/heads/master || BASE=HEAD
  git worktree add -b "$BRANCH_NAME" "$WT_DIR" "$BASE"
fi

for f in AGENT_MANDATES.md AGENTS.md GROK.md GEMINI.md new_agent_prompt standard-plan-compliance-block.md \
         MASTER_AGENT_MANDATE.md MULTI_AGENT_USER_INSTRUCTIONS.md project-facts.md \
         append-to-engineering-log todo-append todo-close get-builds-tag.sh install-merge-drivers.sh \
         .gitattributes run-grok run-grok-planner run-grok-coder run-grok-master run-grok-orchestrator \
         filter-apply-config filter-clean-config project.config.example \
         setup_agent.sh remove_worktree.sh update-rules.sh merge-branch-into-master.sh checkifclean; do
  [[ -e "$ROOT/$f" ]] && cp -a "$ROOT/$f" "$WT_DIR/" 2>/dev/null || true
done
mkdir -p "$WT_DIR/.grok" "$WT_DIR/git-merge-drivers"
[[ -d "$ROOT/.grok" ]] && cp -a "$ROOT/.grok/." "$WT_DIR/.grok/" 2>/dev/null || true
[[ -d "$ROOT/git-merge-drivers" ]] && cp -a "$ROOT/git-merge-drivers/." "$WT_DIR/git-merge-drivers/" 2>/dev/null || true
if [[ ! -e "$WT_DIR/sandbox" && -d "$ROOT/sandbox" ]]; then
  ln -sfn "$ROOT/sandbox" "$WT_DIR/sandbox"
fi
# seed local project.config (never commit)
if [[ ! -f "$WT_DIR/project.config" ]]; then
  if [[ -f "$ROOT/project.config" ]]; then
    cp -a "$ROOT/project.config" "$WT_DIR/project.config"
  elif [[ -f "$ROOT/project.config.example" ]]; then
    cp -a "$ROOT/project.config.example" "$WT_DIR/project.config"
  fi
fi

cat >"$WT_DIR/AGENT_CONTEXT.md" <<ACTX
# AGENT_CONTEXT.md

- **Agent ID:** $BRANCH_NAME
- **Current Branch:** $BRANCH_NAME
- **Role:** coder/planner as launched
- **Sandbox:** $ROOT/sandbox/
- **Status:** ACTIVE
ACTX

if [[ -x "$WT_DIR/install-merge-drivers.sh" ]]; then
  (cd "$WT_DIR" && ./install-merge-drivers.sh) || true
fi

echo "Worktree ready: $WT_DIR"
