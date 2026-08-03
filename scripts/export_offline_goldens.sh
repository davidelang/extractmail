#!/usr/bin/env bash
# Export offline golden JSON (+ optional HTML) for VE assets/email-receipt.
# Usage: scripts/export_offline_goldens.sh [dest_dir]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST=${1:-"$ROOT/../artifact/offline-goldens"}
mkdir -p "$DEST"
cp -f "$ROOT/fixtures/expected-shell-receipt1.json" "$DEST/"
cp -f "$ROOT/fixtures/expected-shell-receipt2.json" "$DEST/"
cp -f "$ROOT/fixtures/expected-sams-club-receipt1.json" "$DEST/"
# HTML optional reference (VE offline path uses JSON only)
cp -f "$ROOT/fixtures/shell-receipt1.html" "$DEST/" 2>/dev/null || true
cp -f "$ROOT/fixtures/shell-receipt2.html" "$DEST/" 2>/dev/null || true
cp -f "$ROOT/fixtures/sams-club-receipt1.html" "$DEST/" 2>/dev/null || true
cat > "$DEST/MANIFEST.txt" <<EOF
extractmail offline goldens for VehicleExpenses assets/email-receipt/
Types: shell-ereceipt, samsclub-fuel (see Extractmail.TYPE_* / extractors/*.yaml)
Canonical numbers: expected-*.json (cost, gallons, timestampMs, …)
Do not require Node on Android — ingest expected JSON.
EOF
echo "Exported offline goldens → $DEST"
ls -la "$DEST"
