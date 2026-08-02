#!/usr/bin/env bash
# Build a minimal Android AAR for extractmail (Kotlin API surface).
# Requires ANDROID_HOME or ANDROID_SDK_ROOT.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
AAR_MOD="$ROOT/android"
OUT_AAR="$ROOT/../artifact/extractmail.aar"
mkdir -p "$(dirname "$OUT_AAR")"

if [ -z "${ANDROID_HOME:-}${ANDROID_SDK_ROOT:-}" ]; then
  if [ -d "$HOME/Android/Sdk" ]; then
    export ANDROID_HOME="$HOME/Android/Sdk"
  elif [ -d /home/dlang/Android/Sdk ]; then
    export ANDROID_HOME=/home/dlang/Android/Sdk
  fi
fi
if [ -z "${ANDROID_HOME:-}" ]; then
  echo "ERROR: ANDROID_HOME not set" >&2
  exit 1
fi

cd "$AAR_MOD"
if [ ! -f gradlew ]; then
  if command -v gradle >/dev/null 2>&1; then
    gradle wrapper --gradle-version 8.7
  else
    echo "ERROR: no gradlew and no gradle on PATH" >&2
    exit 1
  fi
fi
chmod +x gradlew 2>/dev/null || true
./gradlew :extractmail:assembleRelease --no-daemon
BUILT=$(find "$AAR_MOD" -name 'extractmail-release.aar' | head -1)
if [ -z "$BUILT" ] || [ ! -s "$BUILT" ]; then
  echo "ERROR: AAR not produced" >&2
  exit 1
fi
cp -f "$BUILT" "$OUT_AAR"
echo "Wrote $OUT_AAR ($(wc -c < "$OUT_AAR") bytes)"
