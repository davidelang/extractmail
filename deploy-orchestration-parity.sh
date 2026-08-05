#!/usr/bin/env bash
# deploy-orchestration-parity.sh
#
# Human/sudo bootstrap: bring library hosts (+ optional orchestration-example)
# up to VehicleExpenses orchestration tooling parity, with library naming:
#   ve-env              → env
#   ve-refresh-shell*   → refresh-shell*
#   install-ve-refresh* → install-refresh-shell*
#
# ALSO creates/updates ~/git/orchestration-example — orchestration tools only
# (no app product tree) with a drift examiner vs VE and other git_home hosts.
#
# Run as dlang (or root with SUDO_USER=dlang). Needs write under GIT_HOME and
# sudo for setuid refresh-shell + some chgrp/chmod.
#
# Usage:
#   ./deploy-orchestration-parity.sh --dry-run
#   sudo -u dlang ./deploy-orchestration-parity.sh          # if already dlang: ./...
#   ./deploy-orchestration-parity.sh --no-example
#   ./deploy-orchestration-parity.sh --no-commit
#   ./deploy-orchestration-parity.sh --push                 # git push (YOU choose; agents normally don't)
#
# Prerequisites:
#   - VE checkout at VE_ROOT with agent-landlock + updated grok-launch-common
#     (as of 2026-08: agent-landlock may still be untracked on VE — script copies
#     from working tree, not only committed files)
#   - extractmail + remotetable already cloned under GIT_HOME
#
# Does NOT push to GitHub unless --push.
set -euo pipefail

GIT_HOME="${GIT_HOME:-/home/dlang/git}"
VE_ROOT="${VE_ROOT:-$GIT_HOME/VehicleExpenses-automated}"
EM_ROOT="${EM_ROOT:-$GIT_HOME/extractmail}"
RT_ROOT="${RT_ROOT:-$GIT_HOME/remotetable}"
EXAMPLE_ROOT="${EXAMPLE_ROOT:-$GIT_HOME/orchestration-example}"
PRIMARY_USER="${PRIMARY_USER:-dlang}"
CODE_GROUP="${CODE_GROUP:-ai-code}"
SHARED_GROUP="${SHARED_GROUP:-ai-shared}"

DRY=0
DO_EXAMPLE=1
DO_COMMIT=1
DO_PUSH=0
DO_BUILD_REFRESH=1
TARGETS_FILTER=""   # empty=em+rt+example; or em|rt|example|libs

usage() {
  sed -n '2,35p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --no-example) DO_EXAMPLE=0 ;;
    --no-commit) DO_COMMIT=0; DO_PUSH=0 ;;
    --push) DO_PUSH=1 ;;
    --no-build-refresh) DO_BUILD_REFRESH=0 ;;
    --targets)
      shift
      TARGETS_FILTER="${1:-}"
      ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown: $1" >&2; usage 2 ;;
  esac
  shift
done

if [[ "$DRY" -eq 0 && "$(id -un)" != "$PRIMARY_USER" && "$(id -u)" -ne 0 ]]; then
  echo "ERROR: run as $PRIMARY_USER (or root). whoami=$(id -un)" >&2
  echo "  Example: cd $EM_ROOT && sudo -u $PRIMARY_USER ./deploy-orchestration-parity.sh" >&2
  echo "  Dry-run: ./deploy-orchestration-parity.sh --dry-run" >&2
  exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
  RUN_AS="${SUDO_USER:-$PRIMARY_USER}"
  as_user() { runuser -u "$RUN_AS" -- "$@" 2>/dev/null || sudo -u "$RUN_AS" -- "$@"; }
  as_root() { "$@"; }
else
  RUN_AS="$(id -un)"
  as_user() { "$@"; }
  as_root() { sudo "$@"; }
fi

run() {
  if [[ "$DRY" -eq 1 ]]; then echo "  DRY: $*"; else "$@"; fi
}

echo "================================================================"
echo "deploy-orchestration-parity"
echo "  VE_ROOT=$VE_ROOT"
echo "  GIT_HOME=$GIT_HOME  user=$RUN_AS dry=$DRY"
echo "  EM=$EM_ROOT"
echo "  RT=$RT_ROOT"
echo "  EXAMPLE=$EXAMPLE_ROOT (do_example=$DO_EXAMPLE)"
echo "================================================================"

# --- VE readiness ---
need=(
  "$VE_ROOT/agent-landlock"
  "$VE_ROOT/.grok/lib/grok-launch-common.sh"
  "$VE_ROOT/setup_agent.sh"
  "$VE_ROOT/update-rules.sh"
  "$VE_ROOT/remove_worktree.sh"
  "$VE_ROOT/fix-perms"
  "$VE_ROOT/ve-env"
  "$VE_ROOT/ve-refresh-shell.c"
  "$VE_ROOT/install-ve-refresh-shell.sh"
)
missing=0
for f in "${need[@]}"; do
  if [[ ! -e "$f" ]]; then
    echo "ERROR: missing VE source $f" >&2
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  echo "VE landlock/orchestration incomplete. Finish VE agent-landlock work first." >&2
  exit 1
fi

# Soft-check landlock ABI via VE helper
if [[ -x "$VE_ROOT/agent-landlock" || -f "$VE_ROOT/agent-landlock" ]]; then
  echo "VE agent-landlock --status: $(python3 "$VE_ROOT/agent-landlock" --status 2>/dev/null || true)"
fi
if ! grep -q 'agent-landlock' "$VE_ROOT/.grok/lib/grok-launch-common.sh"; then
  echo "WARN: VE grok-launch-common.sh has no agent-landlock wiring yet" >&2
fi

# --- transform helpers (VE names → lib unprefixed) ---
transform_ve_names() {
  # stdin → stdout
  sed \
    -e 's/install-ve-refresh-shell\.sh/install-refresh-shell.sh/g' \
    -e 's/ve-refresh-shell\.c/refresh-shell.c/g' \
    -e 's/ve-refresh-shell/refresh-shell/g' \
    -e 's/\.\/ve-env/\.\/env/g' \
    -e 's/source \.\/ve-env/source .\/env/g' \
    -e 's/"ve-env"/"env"/g' \
    -e 's/ve-env/env/g' \
    -e 's/VE_ENV_CWD/ENV_CWD/g' \
    -e 's/_VE_SOURCED/_ENV_SOURCED/g' \
    -e 's/\b_ve_/_env_/g'
}

copy_transformed() {
  local src="$1" dest="$2" mode="${3:-}"
  [[ -f "$src" ]] || { echo "  skip missing $src"; return 0; }
  if [[ "$DRY" -eq 1 ]]; then
    echo "  DRY: transform $src → $dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  transform_ve_names <"$src" >"$dest"
  if [[ -n "$mode" ]]; then
    chmod "$mode" "$dest"
  elif [[ -x "$src" ]]; then
    chmod 775 "$dest"
  fi
  chown "$RUN_AS:$CODE_GROUP" "$dest" 2>/dev/null || true
  echo "  wrote $dest"
}

copy_raw() {
  local src="$1" dest="$2"
  [[ -e "$src" ]] || { echo "  skip missing $src"; return 0; }
  if [[ "$DRY" -eq 1 ]]; then
    echo "  DRY: cp $src → $dest"
    return 0
  fi
  # Same path (e.g. preferring EM config while dest is EM) — no-op
  if [[ -e "$dest" ]]; then
    local rs rd
    rs=$(readlink -f "$src" 2>/dev/null || realpath "$src" 2>/dev/null || echo "$src")
    rd=$(readlink -f "$dest" 2>/dev/null || realpath "$dest" 2>/dev/null || echo "$dest")
    if [[ "$rs" == "$rd" ]]; then
      echo "  skip same-file $dest"
      return 0
    fi
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -d "$src" && ! -L "$src" ]]; then
    mkdir -p "$dest"
    cp -a "$src"/. "$dest"/
  else
    cp -a "$src" "$dest"
  fi
  chown -R "$RUN_AS:$CODE_GROUP" "$dest" 2>/dev/null || true
  echo "  copied $dest"
}

ensure_git_home_in_project_config() {
  local root="$1"
  local pc="$root/project.config"
  local ex="$root/project.config.example"
  if [[ "$DRY" -eq 1 ]]; then
    echo "  DRY: ensure git_home=$GIT_HOME in $pc"
    return 0
  fi
  if [[ ! -f "$pc" ]]; then
    if [[ -f "$ex" ]]; then
      cp -a "$ex" "$pc"
    else
      cat >"$pc" <<EOF
planning_user=ai-planner
coder_user=ai-coder
orchestrator_user=ai-orchestrator
primary_user=$PRIMARY_USER
code_group=$CODE_GROUP
sandbox_group=ai-sandbox
shared_group=$SHARED_GROUP
sandbox_path=sandbox
sandbox_dir=sandbox
git_home=$GIT_HOME
grok_bin_default=\$HOME/git/grok/bin/grok
gemini_bin_default=\$HOME/git/gemini/bin/gemini
sandbox_special_paths=plans,historical-plans,implementation-failure-logs,PRs,research
EOF
    fi
  fi
  # Apply real values for tokens / ensure git_home
  if grep -q '^git_home=' "$pc"; then
    sed -i "s|^git_home=.*|git_home=$GIT_HOME|" "$pc"
  else
    echo "git_home=$GIT_HOME" >>"$pc"
  fi
  # common sandbox for libs/example
  if grep -q '^sandbox_path=' "$pc"; then
    sed -i 's|^sandbox_path=.*|sandbox_path=sandbox|' "$pc"
  else
    echo "sandbox_path=sandbox" >>"$pc"
  fi
  if ! grep -q '^sandbox_dir=' "$pc"; then
    echo "sandbox_dir=sandbox" >>"$pc"
  else
    sed -i 's|^sandbox_dir=.*|sandbox_dir=sandbox|' "$pc"
  fi
  # strip unresolved @@ if example was copied raw
  sed -i \
    -e "s|@@GIT_HOME@@|$GIT_HOME|g" \
    -e "s|@@SANDBOX_PATH@@|sandbox|g" \
    -e "s|@@PLANNING_USER@@|ai-planner|g" \
    -e "s|@@CODER_USER@@|ai-coder|g" \
    -e "s|@@ORCHESTRATOR_USER@@|ai-orchestrator|g" \
    -e "s|@@PRIMARY_USER@@|$PRIMARY_USER|g" \
    -e "s|@@CODE_GROUP@@|$CODE_GROUP|g" \
    -e "s|@@SANDBOX_GROUP@@|ai-sandbox|g" \
    -e "s|@@SHARED_GROUP@@|$SHARED_GROUP|g" \
    -e "s|@@GROK_BIN_DEFAULT@@|\$HOME/git/grok/bin/grok|g" \
    -e "s|@@GEMINI_BIN_DEFAULT@@|\$HOME/git/gemini/bin/gemini|g" \
    -e "s|@@ANTIGRAVITY_BIN@@|\$HOME/git/antigravity/agy|g" \
    "$pc"
  chown "$RUN_AS:$CODE_GROUP" "$pc" 2>/dev/null || true
  echo "  project.config $(grep -E '^git_home=' "$pc" | head -1)"
}

patch_update_rules_file_list() {
  # After transform, ensure landlock helpers + env names are in FILES= array
  local ur="$1"
  [[ -f "$ur" ]] || return 0
  if [[ "$DRY" -eq 1 ]]; then
    echo "  DRY: patch update-rules FILES for agent-landlock/env"
    return 0
  fi
  if ! grep -q 'agent-landlock' "$ur"; then
    # Insert after env line if present, else after run-grok
    if grep -q '"env"' "$ur"; then
      sed -i '/"env"/a\    "refresh-shell.c"\n    "install-refresh-shell.sh"\n    "agent-landlock"\n    "landlock-smoke-matrix"\n    "landlock-write-probe"\n    "landlock.config"\n    "landlock.config.example"' "$ur"
    else
      sed -i '/"run-grok"/a\    "env"\n    "refresh-shell.c"\n    "install-refresh-shell.sh"\n    "agent-landlock"\n    "landlock-smoke-matrix"\n    "landlock-write-probe"\n    "landlock.config"\n    "landlock.config.example"' "$ur"
    fi
    echo "  patched $ur FILES (+ landlock/env)"
  fi
  # Drop android-only if we want soft-skip: leave listed; update-rules skips missing with -e checks on VE... 
  # VE uses explicit list and cp failures — ensure missing android tools don't break:
  # replace hard fail: no-op — VE update-rules checks file existence per path typically
}

build_refresh_shell() {
  local dest="$1"
  local src_c="$dest/refresh-shell.c"
  local bin="$dest/refresh-shell"
  [[ -f "$src_c" ]] || { echo "  no $src_c — skip build"; return 0; }
  if [[ "$DRY" -eq 1 ]]; then
    echo "  DRY: build+setuid $bin"
    return 0
  fi
  if [[ "$DO_BUILD_REFRESH" -eq 0 ]]; then
    echo "  skip refresh-shell build"
    return 0
  fi
  echo "  Building $bin ..."
  as_user gcc -O2 -Wall -o "$bin" "$src_c"
  chmod a-s "$bin" 2>/dev/null || true
  chmod 755 "$bin"
  as_root chown root:root "$bin"
  as_root chmod 4755 "$bin"
  echo "  OK $(stat -c '%U:%G %a %n' "$bin")"
}

install_git_hooks() {
  local root="$1"
  local tpl="$root/hooks/post-checkout"
  local hookdir
  hookdir="$(git -C "$root" rev-parse --git-path hooks 2>/dev/null || echo "$root/.git/hooks")"
  [[ -f "$tpl" ]] || return 0
  if [[ "$DRY" -eq 1 ]]; then
    echo "  DRY: install post-checkout → $hookdir"
    return 0
  fi
  mkdir -p "$hookdir"
  cp -a "$tpl" "$hookdir/post-checkout"
  chmod 775 "$hookdir/post-checkout"
  echo "  installed $hookdir/post-checkout"
}

sync_orch_tools_into() {
  local dest="$1"
  local kind="$2"   # lib | example
  echo ""
  echo "######################################################################"
  echo "# sync → $dest ($kind)"
  echo "######################################################################"
  if [[ ! -d "$dest" ]]; then
    echo "ERROR: missing $dest" >&2
    return 1
  fi

  # Core from VE with name transform
  copy_transformed "$VE_ROOT/ve-env" "$dest/env" 775
  copy_transformed "$VE_ROOT/ve-refresh-shell.c" "$dest/refresh-shell.c" 664
  copy_transformed "$VE_ROOT/install-ve-refresh-shell.sh" "$dest/install-refresh-shell.sh" 775
  copy_transformed "$VE_ROOT/setup_agent.sh" "$dest/setup_agent.sh" 775
  copy_transformed "$VE_ROOT/remove_worktree.sh" "$dest/remove_worktree.sh" 775
  copy_transformed "$VE_ROOT/update-rules.sh" "$dest/update-rules.sh" 775
  copy_transformed "$VE_ROOT/fix-perms" "$dest/fix-perms" 775
  copy_raw "$VE_ROOT/agent-landlock" "$dest/agent-landlock"
  chmod 775 "$dest/agent-landlock" 2>/dev/null || true
  [[ -f "$VE_ROOT/landlock-smoke-matrix" ]] && copy_raw "$VE_ROOT/landlock-smoke-matrix" "$dest/landlock-smoke-matrix"
  [[ -f "$VE_ROOT/landlock-write-probe" ]] && copy_raw "$VE_ROOT/landlock-write-probe" "$dest/landlock-write-probe"
  chmod 775 "$dest/landlock-smoke-matrix" "$dest/landlock-write-probe" 2>/dev/null || true

  # launch common (already uses agent-landlock name — copy raw then ensure GIT_HOME)
  copy_raw "$VE_ROOT/.grok/lib/grok-launch-common.sh" "$dest/.grok/lib/grok-launch-common.sh"
  chmod 775 "$dest/.grok/lib/grok-launch-common.sh" 2>/dev/null || true

  # landlock + project examples
  copy_raw "$VE_ROOT/landlock.config" "$dest/landlock.config" 2>/dev/null || true
  copy_raw "$VE_ROOT/landlock.config.example" "$dest/landlock.config.example" 2>/dev/null || true
  if [[ ! -f "$dest/landlock.config" && -f "$VE_ROOT/landlock.config.example" ]]; then
    copy_raw "$VE_ROOT/landlock.config.example" "$dest/landlock.config"
  fi

  # hooks template
  mkdir -p "$dest/hooks"
  copy_raw "$VE_ROOT/hooks/post-checkout" "$dest/hooks/post-checkout"
  install_git_hooks "$dest"

  # Other shared helpers if present on dest already or VE
  for f in \
    filter-apply-config filter-clean-config setup-project \
    append-to-engineering-log todo-append todo-close get-builds-tag.sh \
    install-merge-drivers.sh merge-branch-into-master.sh generate_pr.sh \
    run-grok run-grok-orchestrator run-grok-planner run-grok-coder run-grok-master \
    run-antigravity run-antigravity-master run-antigravity-planner \
    project.config.example .gitattributes \
    AGENT_MANDATES.md AGENTS.md GROK.md GEMINI.md new_agent_prompt \
    standard-plan-compliance-block.md MASTER_AGENT_MANDATE.md \
    MULTI_AGENT_USER_INSTRUCTIONS.md project-facts.md
  do
    if [[ -e "$VE_ROOT/$f" ]]; then
      # prefer VE for launchers; for policy docs use VE then leave library-adapted if we want —
      # User asked for app-agnostic policy parity: copy VE app-agnostic scripts; for *MANDATES*
      # keep existing on lib hosts if present and kind=lib (don't clobber library-adapted law
      # unless missing). For example host, always take VE or EM library mandates.
      case "$f" in
        AGENT_MANDATES.md|AGENTS.md|standard-plan-compliance-block.md|MULTI_AGENT_USER_INSTRUCTIONS.md|GROK.md|GEMINI.md|project-facts.md)
          if [[ "$kind" == "lib" && -f "$dest/$f" ]]; then
            echo "  keep existing policy $dest/$f"
            continue
          fi
          ;;
      esac
      copy_raw "$VE_ROOT/$f" "$dest/$f"
    fi
  done

  # .grok prompts/skills from VE (packs)
  if [[ -d "$VE_ROOT/.grok" ]]; then
    if [[ "$DRY" -eq 1 ]]; then
      echo "  DRY: rsync .grok from VE"
    else
      mkdir -p "$dest/.grok"
      # Preserve dest config.toml; merge rest from VE
      if command -v rsync >/dev/null 2>&1; then
        rsync -a --exclude 'config.toml' "$VE_ROOT/.grok/" "$dest/.grok/" || true
      else
        # no rsync: copy tree pieces without clobbering config.toml
        local _save_cfg=""
        if [[ -f "$dest/.grok/config.toml" ]]; then
          _save_cfg=$(mktemp)
          cp -a "$dest/.grok/config.toml" "$_save_cfg"
        fi
        cp -a "$VE_ROOT/.grok/." "$dest/.grok/" || true
        if [[ -n "$_save_cfg" ]]; then
          cp -a "$_save_cfg" "$dest/.grok/config.toml"
          rm -f "$_save_cfg"
        fi
      fi
      # restore launch-common we just set (rsync overwrote)
      copy_raw "$VE_ROOT/.grok/lib/grok-launch-common.sh" "$dest/.grok/lib/grok-launch-common.sh"
      chmod 775 "$dest/.grok/lib/grok-launch-common.sh" 2>/dev/null || true
      if [[ ! -f "$dest/.grok/config.toml" && -f "$VE_ROOT/.grok/config.toml" ]]; then
        copy_raw "$VE_ROOT/.grok/config.toml" "$dest/.grok/config.toml"
      fi
      # library hosts other than extractmail: prefer EM's lib config.toml
      if [[ "$kind" == "lib" && -f "$EM_ROOT/.grok/config.toml" ]]; then
        local _em_cfg _dest_cfg
        _em_cfg=$(readlink -f "$EM_ROOT/.grok/config.toml" 2>/dev/null || echo "$EM_ROOT/.grok/config.toml")
        _dest_cfg=$(readlink -f "$dest/.grok/config.toml" 2>/dev/null || echo "$dest/.grok/config.toml")
        if [[ "$_em_cfg" != "$_dest_cfg" ]]; then
          copy_raw "$EM_ROOT/.grok/config.toml" "$dest/.grok/config.toml"
        else
          echo "  keep existing .grok/config.toml (dest is extractmail)"
        fi
      fi
      chown -R "$RUN_AS:$CODE_GROUP" "$dest/.grok" 2>/dev/null || true
      echo "  synced .grok/"
    fi
  fi

  # git-merge-drivers
  if [[ -d "$VE_ROOT/git-merge-drivers" ]]; then
    copy_raw "$VE_ROOT/git-merge-drivers" "$dest/git-merge-drivers"
  fi

  patch_update_rules_file_list "$dest/update-rules.sh"
  ensure_git_home_in_project_config "$dest"
  build_refresh_shell "$dest"

  # ensure .gitignore has refresh-shell
  if [[ -f "$dest/.gitignore" ]]; then
    if ! grep -qx 'refresh-shell' "$dest/.gitignore" 2>/dev/null; then
      if [[ "$DRY" -eq 0 ]]; then
        printf '\n# refresh-shell: setuid helper binary (built; not in git). Source: refresh-shell.c\nrefresh-shell\n' >>"$dest/.gitignore"
      fi
      echo "  .gitignore + refresh-shell"
    fi
  fi

  # filter config (local git)
  if [[ "$DRY" -eq 0 ]]; then
    git -C "$dest" config filter.manage-configs.smudge 'bash ./filter-apply-config' || true
    git -C "$dest" config filter.manage-configs.clean 'bash ./filter-clean-config %f' || true
    git -C "$dest" config core.sharedRepository group || true
  fi

  echo "  done sync $dest"
}

git_commit_repo() {
  local root="$1"
  local msg="$2"
  if [[ "$DO_COMMIT" -eq 0 || "$DRY" -eq 1 ]]; then
    echo "  skip commit ($root)"
    return 0
  fi
  # Never git add -A: worktrees, nested .git dirs, and junk (e.g. .write-ok)
  # must not become gitlinks or tracked noise.
  local paths=(
    env refresh-shell.c install-refresh-shell.sh
    agent-landlock landlock-smoke-matrix landlock-write-probe
    landlock.config landlock.config.example
    setup_agent.sh remove_worktree.sh update-rules.sh fix-perms
    hooks/post-checkout
    filter-apply-config filter-clean-config setup-project
    append-to-engineering-log todo-append todo-close get-builds-tag.sh
    install-merge-drivers.sh merge-branch-into-master.sh generate_pr.sh
    run-grok run-grok-orchestrator run-grok-planner run-grok-coder run-grok-master
    run-antigravity run-antigravity-master run-antigravity-planner
    project.config.example .gitattributes .gitignore
    new_agent_prompt MASTER_AGENT_MANDATE.md
    .grok/lib/grok-launch-common.sh
    .grok/agents .grok/hooks .grok/prompts .grok/skills
    git-merge-drivers
    deploy-orchestration-parity.sh
    tools docs README.md
    AGENT_CONTEXT.md ENGINEERING_LOG.md TODO.md project-facts.md
  )
  local p
  for p in "${paths[@]}"; do
    if [[ -e "$root/$p" ]]; then
      as_user git -C "$root" add -- "$p" 2>/dev/null || true
    fi
  done
  if as_user git -C "$root" diff --cached --quiet 2>/dev/null; then
    echo "  nothing to commit in $root"
    return 0
  fi
  as_user git -C "$root" commit -m "$msg" || true
  echo "  committed $root"
  if [[ "$DO_PUSH" -eq 1 ]]; then
    local br
    br="$(as_user git -C "$root" rev-parse --abbrev-ref HEAD)"
    echo "  pushing $root ($br)..."
    as_user git -C "$root" push origin "HEAD:refs/heads/$br" \
      || as_user git -C "$root" push push "HEAD:refs/heads/$br" || true
  fi
}

# --- orchestration-example content ---
write_example_readme() {
  local dest="$1"
  [[ "$DRY" -eq 1 ]] && return 0
  cat >"$dest/README.md" <<'EOF'
# orchestration-example

**App-free** multi-agent orchestration host: launchers, policies, Landlock helper,
group-refresh shell, setup/update/fix tooling — **no product application**.

## Purpose

1. Golden layout for standing up a new multi-agent repo next to VehicleExpenses.
2. Drift detection: compare this tree / VE against other clones under `git_home`
   for **orchestration tooling** and **app-agnostic policies**.

## Quick start

```bash
cp project.config.example project.config
# set git_home=/absolute/path/to/git  (required)
source ./env                 # umask 002 + group refresh via ./refresh-shell
./setup_agent.sh my-feature  # creates agent-N worktree
./run-grok-planner
```

Landlock (mutation-only) wraps agents via `agent-landlock` from `run-grok*`.

## Drift report

```bash
./tools/report-orchestration-drift.sh
# or with AI assistance:
#   see docs/ORCHESTRATION_DRIFT.md and tools/prompts/orchestration-drift-agent.md
```

## Relation to VehicleExpenses

VehicleExpenses is the living SoT for orchestration **while** product work continues
there. This repo should track **app-agnostic** copies. Use the drift tool before
porting changes into library hosts (extractmail, remotetable, …).

Library hosts use unprefixed names: `env`, `refresh-shell` (VE still has `ve-*`).
EOF
}

write_drift_docs_and_tool() {
  local dest="$1"
  [[ "$DRY" -eq 1 ]] && return 0
  mkdir -p "$dest/tools/prompts" "$dest/docs" "$dest/sandbox/plans" \
    "$dest/sandbox/research" "$dest/sandbox/PRs" \
    "$dest/sandbox/historical-plans" \
    "$dest/sandbox/implementation-failure-logs"

  cat >"$dest/docs/ORCHESTRATION_DRIFT.md" <<'EOF'
# Orchestration drift (app-agnostic)

## Goal

Detect when multi-agent **tooling** and **process policies** diverge across hosts
under the same `git_home` (e.g. `/home/dlang/git`), using VehicleExpenses as the
default reference **for orchestration**, not for Android/app product code.

## What counts as in-scope

| In scope | Out of scope |
|----------|----------------|
| `run-grok*`, `setup_agent.sh`, `update-rules.sh`, `fix-perms`, `remove_worktree.sh` | App/source trees (`android/`, `python/`, feature code) |
| `env` / `ve-env`, `refresh-shell` / `ve-refresh-shell*`, `agent-landlock` | Product Gradle/SDK paths except as optional landlock profiles |
| `filter-*-config`, `project.config.example`, `landlock.config*` | Pin consumer app code under third_party src |
| `.grok/lib/grok-launch-common.sh`, packs, role prompts | Device/emulator rules unique to VE product |
| Library-adapted `AGENT_MANDATES.md` / STANDARD BLOCK **process** law | VE-only Android device mandates |
| eng-log/TODO helpers, merge drivers, `generate_pr.sh` | |

## Naming map (libs vs VE)

| VE | Library / this example |
|----|-------------------------|
| `ve-env` | `env` |
| `ve-refresh-shell` (+ `.c`, install script) | `refresh-shell` (+ `.c`, `install-refresh-shell.sh`) |
| `dev-ai-interaction/` sandbox | `sandbox/` |

Drift tool treats these pairs as **equivalent paths**.

## How to run

```bash
# machine report (no AI)
./tools/report-orchestration-drift.sh
./tools/report-orchestration-drift.sh --ref /home/dlang/git/VehicleExpenses-automated
./tools/report-orchestration-drift.sh --git-home /home/dlang/git --json

# AI-assisted deep review (paste report + this doc)
# tools/prompts/orchestration-drift-agent.md
```

## Severity guide

- **CRITICAL** — missing launcher, setup_agent cannot seed project.config/smudge, no landlock helper while launch-common expects it, no git_home
- **HIGH** — update-rules/fix-perms/remove_worktree thin stubs vs full VE; env/refresh-shell missing
- **MED** — file present but size/hash drift; policy MD process sections diverged
- **LOW** — comments, Android-only optional files absent on libs (expected)

## When fixing

Prefer: copy/adapt from VE → transform names → library hosts + this example.
Do not invent a third orchestration model.
EOF

  cat >"$dest/tools/prompts/orchestration-drift-agent.md" <<'EOF'
# Agent prompt: orchestration drift review

You are auditing multi-agent **orchestration** hosts under `git_home` for drift
against the reference host (default: VehicleExpenses-automated).

## Rules

1. Ignore product/app code. Only tooling + app-agnostic process policy.
2. Treat `ve-env` ≡ `env`, `ve-refresh-shell*` ≡ `refresh-shell*`, sandbox dir
   `dev-ai-interaction` ≡ `sandbox`.
3. Landlock session helper is `agent-landlock` + wiring in
   `.grok/lib/grok-launch-common.sh`.
4. Report CRITICAL/HIGH/MED/LOW with file paths and recommended fix (copy from
   ref + rename, or document intentional lib adaptation).
5. Do not `git push`. Do not expand into product refactors.

## Inputs

- Output of `./tools/report-orchestration-drift.sh` (attach or re-run).
- `docs/ORCHESTRATION_DRIFT.md`
- `project.config` `git_home=`

## Deliverable

Chat summary + optional `sandbox/research/orchestration-drift-YYYYMMDD.md` if
the user wants a durable cache.
EOF

  cat >"$dest/tools/report-orchestration-drift.sh" <<'EOF'
#!/usr/bin/env bash
# report-orchestration-drift.sh — compare orchestration tooling across git_home hosts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GIT_HOME=""
REF=""
JSON=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --git-home) shift; GIT_HOME="${1:-}" ;;
    --ref) shift; REF="${1:-}" ;;
    --json) JSON=1 ;;
    -h|--help)
      echo "Usage: $0 [--git-home DIR] [--ref DIR] [--json]"
      exit 0
      ;;
    *) echo "Unknown: $1" >&2; exit 2 ;;
  esac
  shift
done

# Resolve git_home
if [[ -z "$GIT_HOME" && -f "$EXAMPLE_ROOT/project.config" ]]; then
  GIT_HOME="$(grep -E '^git_home=' "$EXAMPLE_ROOT/project.config" | head -1 | cut -d= -f2- || true)"
fi
GIT_HOME="${GIT_HOME:-${HOME}/git}"
REF="${REF:-$GIT_HOME/VehicleExpenses-automated}"

if [[ ! -d "$REF" ]]; then
  echo "ERROR: reference not found: $REF" >&2
  exit 1
fi

# Canonical orchestration paths relative to host root.
# Format: canonical_name|ref_relpath|alt_relpath|alt_relpath...
CANON_FILES=(
  "setup_agent.sh|setup_agent.sh"
  "remove_worktree.sh|remove_worktree.sh"
  "update-rules.sh|update-rules.sh"
  "fix-perms|fix-perms"
  "env|ve-env|env"
  "refresh-shell.c|ve-refresh-shell.c|refresh-shell.c"
  "install-refresh-shell.sh|install-ve-refresh-shell.sh|install-refresh-shell.sh"
  "agent-landlock|agent-landlock"
  "landlock-smoke-matrix|landlock-smoke-matrix"
  "landlock-write-probe|landlock-write-probe"
  "landlock.config|landlock.config"
  "landlock.config.example|landlock.config.example"
  "grok-launch-common|.grok/lib/grok-launch-common.sh"
  "run-grok|run-grok"
  "run-grok-orchestrator|run-grok-orchestrator"
  "run-grok-planner|run-grok-planner"
  "run-grok-coder|run-grok-coder"
  "run-grok-master|run-grok-master"
  "filter-apply-config|filter-apply-config"
  "filter-clean-config|filter-clean-config"
  "append-to-engineering-log|append-to-engineering-log"
  "todo-append|todo-append"
  "todo-close|todo-close"
  "get-builds-tag.sh|get-builds-tag.sh"
  "install-merge-drivers.sh|install-merge-drivers.sh"
  "generate_pr.sh|generate_pr.sh"
  "hooks/post-checkout|hooks/post-checkout"
  "project.config.example|project.config.example"
  "AGENT_MANDATES.md|AGENT_MANDATES.md"
  "AGENTS.md|AGENTS.md"
  "standard-plan-compliance-block.md|standard-plan-compliance-block.md"
  "MASTER_AGENT_MANDATE.md|MASTER_AGENT_MANDATE.md"
  "MULTI_AGENT_USER_INSTRUCTIONS.md|MULTI_AGENT_USER_INSTRUCTIONS.md"
)

resolve_file() {
  local root="$1"; shift
  local p
  for p in "$@"; do
    [[ -z "$p" ]] && continue
    if [[ -e "$root/$p" ]]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

# Discover candidate hosts: directories under GIT_HOME that look like multi-agent orch
discover_hosts() {
  local d base
  for d in "$GIT_HOME"/*; do
    [[ -d "$d" ]] || continue
    base="$(basename "$d")"
    [[ "$base" == "orchestration-example" ]] && continue
    if [[ -f "$d/setup_agent.sh" || -f "$d/run-grok-orchestrator" || -f "$d/AGENT_MANDATES.md" ]]; then
      echo "$d"
    fi
  done
}

file_sig() {
  local f="$1"
  if [[ ! -e "$f" ]]; then
    echo "MISSING"
    return
  fi
  local sz md
  sz=$(wc -c <"$f" | tr -d ' ')
  md=$(md5sum "$f" | awk '{print $1}')
  # landlock wiring marker
  local mark=""
  if [[ "$f" == *grok-launch-common.sh ]]; then
    if grep -q 'agent-landlock' "$f" 2>/dev/null; then mark="+landlock"; else mark="-landlock"; fi
  fi
  echo "${sz}:${md}${mark}"
}

echo "=== Orchestration drift report ==="
echo "git_home=$GIT_HOME"
echo "reference=$REF"
echo "generated=$(date -Is)"
echo ""

hosts=()
while IFS= read -r h; do hosts+=("$h"); done < <(discover_hosts)
# always include example if present
if [[ -d "$EXAMPLE_ROOT" ]]; then
  hosts+=("$EXAMPLE_ROOT")
fi

# unique
mapfile -t hosts < <(printf '%s\n' "${hosts[@]}" | awk '!a[$0]++')

if [[ "$JSON" -eq 1 ]]; then
  echo '{"ref":"'"$REF"'","git_home":"'"$GIT_HOME"'","hosts":['
fi

for host in "${hosts[@]}"; do
  [[ "$host" == "$REF" ]] && continue
  name="$(basename "$host")"
  echo "######################################################################"
  echo "# host: $host"
  echo "######################################################################"

  # project.config git_home
  if [[ -f "$host/project.config" ]]; then
    gh=$(grep -E '^git_home=' "$host/project.config" | head -1 || true)
    if [[ -z "$gh" || "$gh" == *@@* ]]; then
      echo "CRITICAL project.config missing/unresolved git_home"
    else
      echo "OK $gh"
    fi
  else
    echo "HIGH project.config missing (gitignored local file)"
  fi

  # refresh-shell setuid
  for cand in refresh-shell ve-refresh-shell; do
    if [[ -e "$host/$cand" ]]; then
      own=$(stat -c '%U:%G %a' "$host/$cand")
      if [[ -u "$host/$cand" && "$(stat -c '%U' "$host/$cand")" == "root" ]]; then
        echo "OK $cand setuid-root ($own)"
      else
        echo "HIGH $cand present but not setuid-root ($own)"
      fi
    fi
  done

  for entry in "${CANON_FILES[@]}"; do
    IFS='|' read -r cname rest <<<"$entry"
    # shellcheck disable=SC2206
    alts=(${rest//|/ })
    ref_rel="$(resolve_file "$REF" "${alts[@]}" || true)"
    host_rel="$(resolve_file "$host" "${alts[@]}" || true)"
    if [[ -z "$ref_rel" && -z "$host_rel" ]]; then
      continue
    fi
    if [[ -z "$host_rel" ]]; then
      # optional android-only tools
      case "$cname" in
        fix-android*|sync-debug*|build_app|deploy) echo "LOW $cname missing on host (optional/product)" ;;
        *) echo "HIGH $cname MISSING on host (ref has ${ref_rel:-?})" ;;
      esac
      continue
    fi
    if [[ -z "$ref_rel" ]]; then
      echo "LOW $cname only on host ($host_rel) not on ref"
      continue
    fi
    rs=$(file_sig "$REF/$ref_rel")
    hs=$(file_sig "$host/$host_rel")
    if [[ "$rs" == "$hs" ]]; then
      echo "OK $cname ($host_rel) match ref"
    else
      # size class
      rsz=${rs%%:*}; hsz=${hs%%:*}
      if [[ "$rs" == MISSING ]]; then
        echo "MED $cname host-only path?"
      elif [[ "$cname" == "setup_agent.sh" || "$cname" == "update-rules.sh" || "$cname" == "fix-perms" || "$cname" == "remove_worktree.sh" ]]; then
        # thin stub heuristic
        if [[ "${hsz:-0}" -lt $((rsz / 3)) ]]; then
          echo "CRITICAL $cname thin stub host=${hsz}B ref=${rsz}B ($host_rel vs $ref_rel)"
        else
          echo "HIGH $cname content drift host=$hs ref=$rs"
        fi
      elif [[ "$cname" == "grok-launch-common" ]]; then
        if [[ "$hs" == *"-landlock"* && "$rs" == *"+landlock"* ]]; then
          echo "CRITICAL grok-launch-common missing agent-landlock wiring"
        else
          echo "HIGH grok-launch-common drift host=$hs ref=$rs"
        fi
      elif [[ "$cname" == AGENT_* || "$cname" == AGENTS.md || "$cname" == standard-plan* || "$cname" == MULTI_AGENT* ]]; then
        echo "MED policy doc drift $cname (may be intentional library adaptation)"
      else
        echo "MED $cname drift host=$hs ref=$rs"
      fi
    fi
  done
  echo ""
done

echo "=== done ==="
echo "See docs/ORCHESTRATION_DRIFT.md for severity and fix guidance."
EOF
  chmod 775 "$dest/tools/report-orchestration-drift.sh"
}

init_example_repo() {
  local dest="$EXAMPLE_ROOT"
  echo ""
  echo "######################################################################"
  echo "# orchestration-example → $dest"
  echo "######################################################################"
  if [[ "$DRY" -eq 1 ]]; then
    echo "  DRY: would create/update $dest"
    return 0
  fi
  if [[ ! -d "$dest" ]]; then
    mkdir -p "$dest"
    as_user git -C "$dest" init -b master
    # shared repo defaults
    as_user git -C "$dest" config core.sharedRepository group
    echo "  git init $dest (master)"
  fi
  # ensure orchestration branch optional — user asked master for drift tool
  # populate tools
  sync_orch_tools_into "$dest" example
  write_example_readme "$dest"
  write_drift_docs_and_tool "$dest"

  # minimal .gitignore
  cat >"$dest/.gitignore" <<'EOF'
project.config
refresh-shell
sandbox/.planning-agent-prompt.txt
*.local
EOF

  # project-facts for example
  cat >"$dest/project-facts.md" <<EOF
# project-facts.md — orchestration-example

- Host: pure multi-agent orchestration template (no app)
- Sandbox: \`sandbox/\`
- git_home: set in project.config to absolute path (e.g. $GIT_HOME)
- Launch: \`./run-grok-*\` via \`.grok/lib/grok-launch-common.sh\` + \`agent-landlock\`
- Groups: source \`./env\` (refresh-shell setuid)
EOF

  # AGENT_CONTEXT for master
  cat >"$dest/AGENT_CONTEXT.md" <<EOF
# AGENT_CONTEXT.md

- **Agent ID:** master
- **Current Branch:** master
- **Role:** template / drift SoT
- **Sandbox:** $dest/sandbox/
- **Status:** ACTIVE
EOF

  # empty eng log / todo for helpers
  if [[ ! -f "$dest/ENGINEERING_LOG.md" ]]; then
    printf '# ENGINEERING_LOG\n\n' >"$dest/ENGINEERING_LOG.md"
  fi
  if [[ ! -f "$dest/TODO.md" ]]; then
    printf '# TODO\n\n' >"$dest/TODO.md"
  fi

  ensure_git_home_in_project_config "$dest"
  chown -R "$RUN_AS:$CODE_GROUP" "$dest" 2>/dev/null || true

  git_commit_repo "$dest" "chore: orchestration-example tools + drift examiner

App-free multi-agent host mirrored from VehicleExpenses orchestration stack
(with env/refresh-shell unprefixed names). Includes tools/report-orchestration-drift.sh
and docs for comparing git_home hosts."
}

# --- root setgid note (optional) ---
fix_root_setgid() {
  local root="$1"
  if [[ "$DRY" -eq 1 ]]; then
    echo "  DRY: chmod 2775 + chgrp $CODE_GROUP $root"
    return 0
  fi
  as_root chgrp "$CODE_GROUP" "$root" 2>/dev/null || true
  as_root chmod 2775 "$root" 2>/dev/null || true
  echo "  root mode $(stat -c '%a %U:%G' "$root")"
}

# ========== main ==========
do_em=0; do_rt=0; do_ex=0
case "${TARGETS_FILTER:-}" in
  ""|all|libs)
    do_em=1; do_rt=1
    [[ "$DO_EXAMPLE" -eq 1 ]] && do_ex=1
    [[ "$TARGETS_FILTER" == "libs" ]] && do_ex=0
    ;;
  em|extractmail) do_em=1 ;;
  rt|remotetable) do_rt=1 ;;
  example) do_ex=1; DO_EXAMPLE=1 ;;
  *) echo "Bad --targets"; exit 2 ;;
esac

if [[ "$do_em" -eq 1 ]]; then
  sync_orch_tools_into "$EM_ROOT" lib
  fix_root_setgid "$EM_ROOT"
  git_commit_repo "$EM_ROOT" "chore: orchestration parity with VE (landlock, setup/update, env)

Port session agent-landlock, thick setup_agent/update-rules/remove_worktree/fix-perms,
hooks, and unprefixed env/refresh-shell. project.config git_home absolute."
fi

if [[ "$do_rt" -eq 1 ]]; then
  if [[ ! -d "$RT_ROOT" ]]; then
    echo "WARN: remotetable missing at $RT_ROOT — skip"
  else
    sync_orch_tools_into "$RT_ROOT" lib
    fix_root_setgid "$RT_ROOT"
    git_commit_repo "$RT_ROOT" "chore: orchestration parity with VE (landlock, setup/update, env)

Port session agent-landlock, thick setup_agent/update-rules/remove_worktree/fix-perms,
hooks, and unprefixed env/refresh-shell. project.config git_home absolute."
  fi
fi

if [[ "$DO_EXAMPLE" -eq 1 && "$do_ex" -eq 1 ]]; then
  init_example_repo
  fix_root_setgid "$EXAMPLE_ROOT"
fi

echo ""
echo "================================================================"
echo "DONE"
echo ""
echo "As $PRIMARY_USER (groups may need: source ./env):"
echo "  cd $EM_ROOT && source ./env && ./agent-landlock --status"
echo "  ./agent-landlock --role orchestrator --worktree \$PWD --dump-grants | head"
echo "  # smoke sibling deny:"
echo "  ./agent-landlock --role orchestrator --worktree \$PWD -- \\\\"
echo "    bash -c 'echo x > $RT_ROOT/.should-fail 2>&1 || echo BLOCKED_OK'"
if [[ "$DO_EXAMPLE" -eq 1 ]]; then
  echo "  $EXAMPLE_ROOT/tools/report-orchestration-drift.sh | less"
fi
echo ""
echo "If VE agent-landlock was still untracked, commit it on VE too so SoT is git-visible."
echo "================================================================"
