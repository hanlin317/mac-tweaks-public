#!/bin/bash
# Snapshot the current BTT triggers into config/btt/ without touching BTT.
set -euo pipefail
cd "$(dirname "$0")/.."
out="config/btt/btt-triggers-$(date +%F).json"
osascript -e 'tell application "BetterTouchTool" to get_triggers' > "$out"
echo "wrote $out"
