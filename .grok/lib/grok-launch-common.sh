# grok-launch-common.sh — shared machinery for run-grok* (no project law).
# Install at: <repo>/.grok/lib/grok-launch-common.sh
# Thin wrappers set GROK_LAUNCHER_DIR + ROLE_KEY, then source this and call grok_launch_main "$@".
#
# Rules: only in files listed by .grok/prompts/packs/<ROLE_KEY>.pack
# Wiring: project.config (users, sandbox_dir, optional *_model)
#
# shellcheck shell=bash

set -euo pipefail

if [[ -z "${GROK_LAUNCHER_DIR:-}" ]]; then
  echo "ERROR: GROK_LAUNCHER_DIR must be set to the repository worktree root" >&2
  exit 2
fi
SCRIPT_DIR="$(cd "$GROK_LAUNCHER_DIR" && pwd)"

if [[ -f "$SCRIPT_DIR/project.config" ]]; then
  # KEY=VALUE lines only (skip comments/blank). Keep equals — do not split on '='.
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]] || continue
    # shellcheck disable=SC2163
    export "$line"
  done <"$SCRIPT_DIR/project.config"
fi

GROK_BIN="${GROK_BIN:-${grok_bin:-$HOME/git/grok/bin/grok}}"

# Prefer sandbox_dir; accept legacy sandbox_path (VE filters/example).
SANDBOX_REL="${sandbox_dir:-${sandbox_path:-}}"
if [[ -z "$SANDBOX_REL" ]]; then
  if [[ -d "$SCRIPT_DIR/dev-ai-interaction" ]]; then
    SANDBOX_REL="dev-ai-interaction"
  elif [[ -d "$SCRIPT_DIR/sandbox" ]]; then
    SANDBOX_REL="sandbox"
  else
    SANDBOX_REL="sandbox"
  fi
fi
if [[ "$SANDBOX_REL" = /* ]]; then
  SANDBOX_DIR="$SANDBOX_REL"
else
  SANDBOX_DIR="$SCRIPT_DIR/$SANDBOX_REL"
fi

COMPOSE="${SCRIPT_DIR}/.grok/prompts/compose-session-prompt.sh"
if [[ ! -f "$COMPOSE" ]]; then
  echo "ERROR: missing $COMPOSE" >&2
  exit 1
fi
[[ -x "$COMPOSE" ]] || chmod +x "$COMPOSE" 2>/dev/null || true

ANDROID_SHARED=""
if [[ -d "$SCRIPT_DIR/.android-shared" ]]; then
  ANDROID_SHARED="$SCRIPT_DIR/.android-shared"
elif [[ -d "$SCRIPT_DIR/../.android-shared" ]]; then
  ANDROID_SHARED="$(cd "$SCRIPT_DIR/.." && pwd)/.android-shared"
fi

umask "${umask_launch:-002}"

PACK_PATHS=()
EXTRA_ARGS=()
MODEL_ARGS=()
TODO_GATE_FLAGS=()
PROMPT_FILE=""
PROMPT=""

resolve_pack_file() {
  if [[ -n "${PACK_FILE:-}" ]]; then
    if [[ "$PACK_FILE" = /* ]]; then echo "$PACK_FILE"; else echo "$SCRIPT_DIR/$PACK_FILE"; fi
    return
  fi
  if [[ -z "${ROLE_KEY:-}" ]]; then
    echo "ERROR: ROLE_KEY or PACK_FILE required" >&2
    exit 2
  fi
  local f="$SCRIPT_DIR/.grok/prompts/packs/${ROLE_KEY}.pack"
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing pack list: $f" >&2
    echo "Add one repo-relative prompt path per line (project rules live in those files)." >&2
    exit 1
  fi
  echo "$f"
}

read_pack_paths() {
  local packf="$1" line
  PACK_PATHS=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    PACK_PATHS+=("$line")
  done <"$packf"
  if [[ ${#PACK_PATHS[@]} -eq 0 ]]; then
    echo "ERROR: pack file empty: $packf" >&2
    exit 1
  fi
}

compose_prompt() {
  export GROK_PROMPT_ROOT="$SCRIPT_DIR"
  "$COMPOSE" "${PACK_PATHS[@]}"
}

resolve_run_user() {
  case "${ROLE_KEY:-}" in
    planner) echo "${planning_user:-ai-planner}" ;;
    coder) echo "${coder_user:-ai-coder}" ;;
    master) echo "${master_user:-${coder_user:-ai-coder}}" ;;
    orchestrator) echo "${orchestrator_user:-ai-orchestrator}" ;;
    primary) echo "${primary_user:-${SUDO_USER:-${USER:-dlang}}}" ;;
    *) echo "${primary_user:-${USER:-dlang}}" ;;
  esac
}

build_model_args() {
  MODEL_ARGS=()
  if [[ -n "${FORCE_MODEL:-}" ]]; then
    MODEL_ARGS=(--model "$FORCE_MODEL"); return
  fi
  if [[ -n "${GROK_FORCE_MODEL:-}" ]]; then
    MODEL_ARGS=(--model "$GROK_FORCE_MODEL"); return
  fi
  local v=""
  case "${ROLE_KEY:-}" in
    planner) v="${planner_model:-${GROK_PLANNER_MODEL:-}}" ;;
    coder) v="${coder_model:-}" ;;
    master) v="${master_model:-}" ;;
    orchestrator) v="${orchestrator_model:-}" ;;
    primary) v="${primary_model:-}" ;;
  esac
  [[ -n "$v" ]] && MODEL_ARGS=(--model "$v")
}

build_todo_gate_flags() {
  TODO_GATE_FLAGS=()
  if [[ "${GROK_TODO_GATE:-0}" = "1" || "${GROK_TODO_GATE:-0}" = "true" ]]; then
    TODO_GATE_FLAGS=(--todo-gate)
  fi
}

collect_extra_args() {
  EXTRA_ARGS=()
  local found=0 a
  for a in "$@"; do
    if [[ "$found" -eq 1 ]]; then
      EXTRA_ARGS+=("$a")
    elif [[ "$a" = "--" ]]; then
      found=1
    fi
  done
}

# Build PROMPT from pack files and/or optional prompt file argument.
prepare_prompt() {
  PROMPT_FILE=""
  PACK_PATHS=()

  # Explicit prompt file as first argument (e.g. master-written planner prompt)
  if [[ -n "${1:-}" && -f "${1:-}" ]]; then
    PROMPT_FILE="$1"
    shift
    PROMPT="$(cat "$PROMPT_FILE")"
    collect_extra_args "$@"
    return
  fi
  collect_extra_args "$@"

  local packf default_prompt
  packf="$(resolve_pack_file)"
  read_pack_paths "$packf"

  default_prompt="${SANDBOX_DIR}/.planning-agent-prompt.txt"
  if [[ "${ROLE_KEY:-}" = "planner" \
     && -f "$default_prompt" \
     && "${GROK_IGNORE_PLANNING_PROMPT_FILE:-0}" != "1" ]]; then
    PROMPT_FILE="$default_prompt"
    PROMPT="$(cat "$PROMPT_FILE")"
    return
  fi

  PROMPT="$(compose_prompt)"

  if [[ "${ROLE_KEY:-}" = "planner" && "${GROK_WRITE_PLANNING_PROMPT_FILE:-1}" = "1" ]]; then
    mkdir -p "$SANDBOX_DIR"
    printf '%s\n' "$PROMPT" >"$default_prompt"
    PROMPT_FILE="$default_prompt"
  fi
}

launch_grok_with_prompt() {
  local prompt="$1"
  local run_user
  run_user="$(resolve_run_user)"
  build_model_args
  build_todo_gate_flags

  echo "Launching Grok role=${ROLE_KEY:-?} root=$SCRIPT_DIR"
  echo "Grok binary: $GROK_BIN"
  echo "Sandbox: $SANDBOX_DIR"
  echo "Running as: $run_user"
  [[ -n "${PROMPT_FILE:-}" ]] && echo "Prompt file: $PROMPT_FILE"
  if [[ ${#PACK_PATHS[@]} -gt 0 ]]; then
    echo "Prompt pack: ${PACK_PATHS[*]}"
  fi
  [[ -n "$ANDROID_SHARED" ]] && echo "ANDROID_USER_HOME: $ANDROID_SHARED"
  echo "Tip: Ctrl+M or /multiline for multi-line input."

  exec sudo -u "$run_user" -- env \
    ${ANDROID_SHARED:+ANDROID_USER_HOME="$ANDROID_SHARED"} \
    GROK_PROMPT_ROOT="$SCRIPT_DIR" \
    bash -c 'umask '"${umask_launch:-002}"'; exec "$@"' bash \
      "$GROK_BIN" \
      "$prompt" \
      ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} \
      ${TODO_GATE_FLAGS[@]+"${TODO_GATE_FLAGS[@]}"} \
      --no-alt-screen \
      ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
}

grok_launch_main() {
  prepare_prompt "$@"
  launch_grok_with_prompt "$PROMPT"
}
