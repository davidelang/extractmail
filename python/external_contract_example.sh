#!/usr/bin/env bash
# Example external extractor wrapper (exit 0/1/2).
# Real deployments replace body with a package-specific binary.
set -euo pipefail
TYPE=${1:-auto}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
exec python3 "$ROOT/python/extractmail_stdin.py" --type "$TYPE"
