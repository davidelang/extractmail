#!/usr/bin/env bash
# merge-branch-into-master.sh — library host (slim).
# Usage (on master worktree): ./merge-branch-into-master.sh <branch-name>
# Leaves merge UNCOMMITTED for master review. Installs merge drivers if present.
set -euo pipefail
BRANCH="${1:-}"
[[ -n "$BRANCH" ]] || { echo "Usage: $0 <branch-name>" >&2; exit 1; }
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"
CUR=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CUR" != "master" ]]; then
  echo "WARNING: on '$CUR' (expected master). Continuing." >&2
fi
git rev-parse --verify "$BRANCH" >/dev/null
if [[ -x ./install-merge-drivers.sh ]]; then
  ./install-merge-drivers.sh >/dev/null || true
fi
# Prefer no-ff no-commit for review
if git merge-base --is-ancestor HEAD "$BRANCH" 2>/dev/null; then
  echo "Fast-forward possible; still using --no-ff --no-commit for review."
fi
git merge --no-ff --no-commit "$BRANCH"
echo "Merge staged (uncommitted). Review, fix specials (TODO/eng-log), then commit."
