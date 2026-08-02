#!/usr/bin/env bash
# setup_agent.sh — library host (remotetable/extractmail). Copy-adapted from VE (slim).
# Usage (from library orchestration root): ./setup_agent.sh <branch-name>
# Creates worktree ./<branch-name> or ./agent-N style dir from branch.
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

# Prefer branch-named worktree dir (same as VE branch when co-dev)
WT_DIR="$ROOT/$BRANCH_NAME"
if [[ -d "$WT_DIR" ]]; then
  echo "Worktree already exists: $WT_DIR"
  exit 0
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  git worktree add "$WT_DIR" "$BRANCH_NAME"
else
  # base master if present
  BASE=master
  git show-ref --verify --quiet refs/heads/master || BASE=HEAD
  git worktree add -b "$BRANCH_NAME" "$WT_DIR" "$BASE"
fi

# Sync policy files from orchestration root into new worktree
for f in AGENT_MANDATES.md AGENTS.md GROK.md new_agent_prompt standard-plan-compliance-block.md \
         MASTER_AGENT_MANDATE.md MULTI_AGENT_USER_INSTRUCTIONS.md project-facts.md \
         append-to-engineering-log todo-append todo-close get-builds-tag.sh install-merge-drivers.sh \
         .gitattributes run-grok run-grok-planner run-grok-coder run-grok-master run-grok-orchestrator \
         filter-apply-config filter-clean-config project.config; do
  [[ -e "$ROOT/$f" ]] && cp -a "$ROOT/$f" "$WT_DIR/" 2>/dev/null || true
done
mkdir -p "$WT_DIR/.grok" "$WT_DIR/git-merge-drivers"
[[ -d "$ROOT/.grok" ]] && cp -a "$ROOT/.grok/." "$WT_DIR/.grok/" 2>/dev/null || true
[[ -d "$ROOT/git-merge-drivers" ]] && cp -a "$ROOT/git-merge-drivers/." "$WT_DIR/git-merge-drivers/" 2>/dev/null || true
if [[ ! -e "$WT_DIR/sandbox" && -d "$ROOT/sandbox" ]]; then
  ln -sfn "$ROOT/sandbox" "$WT_DIR/sandbox"
fi

cat >"$WT_DIR/AGENT_CONTEXT.md" <<EOF
# AGENT_CONTEXT.md

- **Agent ID:** $BRANCH_NAME
- **Current Branch:** $BRANCH_NAME
- **Role:** coder/planner as launched
- **Sandbox:** $ROOT/sandbox/
- **Status:** ACTIVE
EOF

(
  cd "$WT_DIR"
  ./install-merge-drivers.sh 2>/dev/null || true
)

echo "Created worktree: $WT_DIR (branch $BRANCH_NAME)"
echo "Launch e.g.: cd $WT_DIR && ../run-grok-coder   # or copy launchers already in tree"
