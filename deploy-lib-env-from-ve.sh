#!/usr/bin/env bash
# deploy-lib-env-from-ve.sh — copy VehicleExpenses ve-env stack into library hosts
# with the "ve-" prefix dropped, build setuid helper, commit, and push to GitHub.
#
# Source (VE SoT):
#   ve-env                  → env
#   ve-refresh-shell.c      → refresh-shell.c
#   install-ve-refresh-shell.sh → install-refresh-shell.sh
#   ve-refresh-shell        → refresh-shell   (built binary; NOT committed)
#
# Targets (orchestration roots):
#   this repo (extractmail) and ../remotetable
#
# Run as dlang with sudo rights, or via sudo (git/push run as the invoking user):
#   ./deploy-lib-env-from-ve.sh
#   sudo ./deploy-lib-env-from-ve.sh
#   ./deploy-lib-env-from-ve.sh --dry-run
#   ./deploy-lib-env-from-ve.sh --no-push
#   ./deploy-lib-env-from-ve.sh --no-build
#   ./deploy-lib-env-from-ve.sh --repos extractmail
#
# Requires: gcc, git, SSH access to github.com as the non-root user (for --push).
set -euo pipefail

DRY=0
DO_PUSH=1
DO_BUILD=1
DO_COMMIT=1
REPO_FILTER=""   # empty = both; or extractmail|remotetable|both
VE_ROOT="${VE_ROOT:-/home/dlang/git/VehicleExpenses-automated}"
GIT_HOME="${GIT_HOME:-/home/dlang/git}"
PRIMARY_USER="${PRIMARY_USER:-dlang}"
CODE_GROUP="${CODE_GROUP:-ai-code}"

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --no-push) DO_PUSH=0 ;;
    --no-build) DO_BUILD=0 ;;
    --no-commit) DO_COMMIT=0; DO_PUSH=0 ;;
    --repos)
      shift
      REPO_FILTER="${1:-}"
      [[ -n "$REPO_FILTER" ]] || { echo "ERROR: --repos needs extractmail|remotetable|both" >&2; exit 2; }
      ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown arg: $1" >&2; usage 2 ;;
  esac
  shift
done

# Who should own files and run git/push?
if [[ "$(id -u)" -eq 0 ]]; then
  RUN_AS="${SUDO_USER:-$PRIMARY_USER}"
  if [[ -z "$RUN_AS" || "$RUN_AS" == "root" ]]; then
    RUN_AS="$PRIMARY_USER"
  fi
  as_user() {
    if command -v runuser >/dev/null 2>&1; then
      runuser -u "$RUN_AS" -- "$@"
    else
      sudo -u "$RUN_AS" -- "$@"
    fi
  }
  as_root() { "$@"; }
else
  RUN_AS="$(id -un)"
  as_user() { "$@"; }
  as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
      "$@"
    elif command -v sudo >/dev/null 2>&1; then
      sudo "$@"
    else
      echo "ERROR: need root/sudo for: $*" >&2
      return 1
    fi
  }
fi

run() {
  if [[ "$DRY" -eq 1 ]]; then
    echo "  DRY: $*"
  else
    "$@"
  fi
}

echo "================================================================"
echo "deploy-lib-env-from-ve"
echo "  VE_ROOT=$VE_ROOT"
echo "  GIT_HOME=$GIT_HOME"
echo "  run as user=$RUN_AS  euid=$(id -u)  dry=$DRY push=$DO_PUSH build=$DO_BUILD commit=$DO_COMMIT"
echo "================================================================"

# --- validate sources ---
need_src=(
  "$VE_ROOT/ve-env"
  "$VE_ROOT/ve-refresh-shell.c"
  "$VE_ROOT/install-ve-refresh-shell.sh"
)
for f in "${need_src[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing source $f" >&2
    exit 1
  fi
done

# --- transform VE text → unprefixed lib names ---
# Order matters: longer tokens first.
transform_text() {
  # stdin → stdout
  # Longer / more specific tokens first.
  sed \
    -e 's/install-ve-refresh-shell\.sh/install-refresh-shell.sh/g' \
    -e 's/ve-refresh-shell\.c/refresh-shell.c/g' \
    -e 's/ve-refresh-shell/refresh-shell/g' \
    -e 's/VE_ENV_CWD/ENV_CWD/g' \
    -e 's/_VE_SOURCED/_ENV_SOURCED/g' \
    -e 's/\b_ve_/_env_/g' \
    -e 's/ve-env/env/g'
}

write_transformed() {
  local src="$1" dest="$2" mode="$3"
  local tmp
  tmp="$(mktemp)"
  transform_text <"$src" >"$tmp"
  if [[ "$DRY" -eq 1 ]]; then
    echo "  DRY: would write $dest (mode $mode, $(wc -c <"$tmp") bytes)"
    rm -f "$tmp"
    return 0
  fi
  install -m "$mode" -o "$RUN_AS" -g "$CODE_GROUP" "$tmp" "$dest" 2>/dev/null \
    || { cp -f "$tmp" "$dest"; chown "$RUN_AS:$CODE_GROUP" "$dest" 2>/dev/null || true; chmod "$mode" "$dest"; }
  rm -f "$tmp"
  echo "  wrote $dest"
}

ensure_gitignore_refresh_shell() {
  local gi="$1/.gitignore"
  local marker='# refresh-shell: setuid helper binary (built; not in git). Source: refresh-shell.c'
  if [[ "$DRY" -eq 1 ]]; then
    echo "  DRY: ensure $gi ignores refresh-shell"
    return 0
  fi
  if [[ ! -f "$gi" ]]; then
    cat >"$gi" <<EOF
$marker
refresh-shell
EOF
    chown "$RUN_AS:$CODE_GROUP" "$gi" 2>/dev/null || true
    echo "  created $gi"
    return 0
  fi
  if grep -qx 'refresh-shell' "$gi" 2>/dev/null; then
    echo "  .gitignore already ignores refresh-shell"
    return 0
  fi
  {
    echo ""
    echo "$marker"
    echo "refresh-shell"
  } >>"$gi"
  chown "$RUN_AS:$CODE_GROUP" "$gi" 2>/dev/null || true
  echo "  updated $gi (+ refresh-shell)"
}

patch_setup_agent_copy_list() {
  local sa="$1/setup_agent.sh"
  [[ -f "$sa" ]] || { echo "  skip setup_agent (missing)"; return 0; }
  if grep -q 'install-refresh-shell\.sh' "$sa" 2>/dev/null; then
    echo "  setup_agent already lists env helpers"
    return 0
  fi
  if [[ "$DRY" -eq 1 ]]; then
    echo "  DRY: would patch $sa copy list for env/refresh-shell"
    return 0
  fi
  # Insert after project.config.example on the filter-apply line block
  if grep -q 'project.config.example' "$sa"; then
    sed -i \
      -e 's|project.config.example \\|project.config.example env refresh-shell.c install-refresh-shell.sh \\|' \
      "$sa"
    chown "$RUN_AS:$CODE_GROUP" "$sa" 2>/dev/null || true
    echo "  patched $sa (copy env + refresh-shell.c + install-refresh-shell.sh into worktrees)"
  else
    echo "  WARN: could not patch $sa (no project.config.example line)" >&2
  fi
}

build_and_setuid() {
  local dest="$1"
  local src_c="$dest/refresh-shell.c"
  local bin="$dest/refresh-shell"
  if [[ "$DRY" -eq 1 ]]; then
    echo "  DRY: would gcc + chown root + chmod 4755 $bin"
    return 0
  fi
  [[ -f "$src_c" ]] || { echo "  ERROR: no $src_c" >&2; return 1; }
  echo "  Building $bin ..."
  as_user gcc -O2 -Wall -o "$bin" "$src_c"
  # Never leave setuid on non-root ownership
  chmod a-s "$bin" 2>/dev/null || true
  chmod 755 "$bin"
  as_root chown root:root "$bin"
  as_root chmod 4755 "$bin"
  echo "  OK setuid: $(stat -c '%U:%G %a %n' "$bin")"
}

install_into_worktrees() {
  local orch="$1"
  local f
  # copy tracked helpers into known worktrees (binary built separately)
  while read -r wt; do
    [[ -n "$wt" && -d "$wt" ]] || continue
    [[ "$wt" == "$orch" ]] && continue
    echo "  worktree: $wt"
    for f in env refresh-shell.c install-refresh-shell.sh; do
      if [[ "$DRY" -eq 1 ]]; then
        echo "    DRY: cp $f → $wt/"
        continue
      fi
      if [[ -f "$orch/$f" ]]; then
        cp -a "$orch/$f" "$wt/$f"
        chown "$RUN_AS:$CODE_GROUP" "$wt/$f" 2>/dev/null || true
      fi
    done
    if [[ "$DO_BUILD" -eq 1 ]]; then
      build_and_setuid "$wt" || echo "    WARN: build/setuid failed in $wt" >&2
    fi
  done < <(as_user git -C "$orch" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}')
}

git_commit_and_push() {
  local root="$1"
  local msg="$2"
  if [[ "$DO_COMMIT" -eq 0 ]]; then
    echo "  skip commit"
    return 0
  fi
  if [[ "$DRY" -eq 1 ]]; then
    echo "  DRY: would git add/commit in $root"
    [[ "$DO_PUSH" -eq 1 ]] && echo "  DRY: would git push"
    return 0
  fi

  local paths=(env refresh-shell.c install-refresh-shell.sh .gitignore setup_agent.sh)
  # Deploy script itself lives only in extractmail
  if [[ -f "$root/deploy-lib-env-from-ve.sh" ]]; then
    paths+=(deploy-lib-env-from-ve.sh)
  fi
  as_user git -C "$root" add -- "${paths[@]}" 2>/dev/null || true
  if as_user git -C "$root" diff --cached --quiet 2>/dev/null; then
    if as_user git -C "$root" status --porcelain -- "${paths[@]}" | grep -q .; then
      as_user git -C "$root" add -- "${paths[@]}"
    fi
  fi
  if as_user git -C "$root" diff --cached --quiet 2>/dev/null; then
    echo "  nothing to commit in $root"
  else
    as_user git -C "$root" commit -m "$msg"
    echo "  committed in $root"
  fi

  if [[ "$DO_PUSH" -eq 1 ]]; then
    local branch
    branch="$(as_user git -C "$root" rev-parse --abbrev-ref HEAD)"
    echo "  pushing $root ($branch) → origin ..."
    # Prefer remote "push" if present (lib hosts often have it), else origin
    if as_user git -C "$root" remote get-url push >/dev/null 2>&1; then
      as_user git -C "$root" push push "HEAD:refs/heads/$branch" \
        || as_user git -C "$root" push origin "HEAD:refs/heads/$branch"
    else
      as_user git -C "$root" push -u origin "HEAD:refs/heads/$branch"
    fi
    echo "  pushed $root"
  else
    echo "  skip push (--no-push)"
  fi
}

deploy_repo() {
  local name="$1"
  local root="$GIT_HOME/$name"
  echo ""
  echo "######################################################################"
  echo "# $root"
  echo "######################################################################"
  if [[ ! -d "$root/.git" && ! -f "$root/.git" ]]; then
    echo "ERROR: not a git repo: $root" >&2
    return 1
  fi

  write_transformed "$VE_ROOT/ve-env" "$root/env" 775
  write_transformed "$VE_ROOT/ve-refresh-shell.c" "$root/refresh-shell.c" 664
  write_transformed "$VE_ROOT/install-ve-refresh-shell.sh" "$root/install-refresh-shell.sh" 775
  ensure_gitignore_refresh_shell "$root"
  patch_setup_agent_copy_list "$root"

  if [[ "$DO_BUILD" -eq 1 ]]; then
    build_and_setuid "$root"
    install_into_worktrees "$root"
  else
    echo "  skip build (--no-build)"
  fi

  git_commit_and_push "$root" \
    "chore: add env + refresh-shell (from VE ve-env, unprefixed)

Copy multi-user shell helper from VehicleExpenses:
- env (source ./env) — umask 002 + stale-group re-exec
- refresh-shell.c / install-refresh-shell.sh — setuid initgroups helper
- gitignore refresh-shell binary; setup_agent copies helpers into worktrees

Binary is built locally as setuid root; not committed."
}

# --- select repos ---
repos=()
case "${REPO_FILTER:-both}" in
  both|"")
    repos=(extractmail remotetable)
    ;;
  extractmail|remotetable)
    repos=("$REPO_FILTER")
    ;;
  *)
    echo "ERROR: --repos must be extractmail, remotetable, or both" >&2
    exit 2
    ;;
esac

# Always resolve extractmail path relative to this script if present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/.git" || -f "$SCRIPT_DIR/.git" ]]; then
  # Prefer script's repo as extractmail when name matches
  if [[ "$(basename "$SCRIPT_DIR")" == "extractmail" ]]; then
    GIT_HOME="$(dirname "$SCRIPT_DIR")"
  fi
fi

fail=0
for r in "${repos[@]}"; do
  deploy_repo "$r" || fail=1
done

echo ""
echo "================================================================"
if [[ "$fail" -ne 0 ]]; then
  echo "DONE with errors"
  exit 1
fi
echo "DONE"
echo ""
echo "As $PRIMARY_USER (or after group refresh):"
echo "  cd $GIT_HOME/extractmail && source ./env"
echo "  id -nG | tr ' ' '\\n' | grep -E 'ai-(code|shared|sandbox)'"
echo "  ./env check"
echo "================================================================"
exit 0
