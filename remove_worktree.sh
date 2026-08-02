#!/usr/bin/env bash
# remove_worktree.sh — library host slim. Usage: ./remove_worktree.sh [-f] branch-or-dir
set -euo pipefail

FORCE=0
TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) FORCE=1; shift ;;
    *) TARGET="$1"; shift ;;
  esac
done
[[ -n "$TARGET" ]] || { echo "Usage: $0 [-f] branch-or-dir" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [[ -d "$TARGET" ]]; then
  WT="$TARGET"
  BR="$(git -C "$WT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
else
  BR="$TARGET"
  WT="$(git worktree list --porcelain | awk -v b="refs/heads/$BR" '
    $1=="worktree"{w=$2} $1=="branch" && $2==b {print w; exit}')"
fi

[[ -n "${WT:-}" && -d "$WT" ]] || { echo "worktree not found for $TARGET" >&2; exit 1; }
[[ "$WT" == "$ROOT" || "$WT" == "$ROOT/"* ]] || { echo "refusing path outside repo: $WT" >&2; exit 1; }
[[ "$(basename "$WT")" != "master" ]] || { echo "refusing to remove master worktree" >&2; exit 1; }

if [[ "$FORCE" -eq 0 ]]; then
  if [[ -n "$(git -C "$WT" status --porcelain 2>/dev/null)" ]]; then
    echo "Worktree dirty; use -f to force remove" >&2
    exit 1
  fi
fi

echo "Removing worktree $WT (branch ${BR:-?})"
chmod -R u+w "$WT" 2>/dev/null || true
git worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
echo "Done. Branch $BR may still exist locally (delete manually if desired)."
