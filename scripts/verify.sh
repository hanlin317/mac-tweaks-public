#!/bin/bash
# Read-only health check for the live setup. Prints OK/WARN/FAIL for each item.
# It never modifies BTT, SketchyBar or any config.
set -u
H="$HOME/.config/sketchybar/helper"
P="$HOME/.config/sketchybar/plugins"
fails=0
warns=0

ok()   { printf 'OK    %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; warns=$((warns+1)); }
bad()  { printf 'FAIL  %s\n' "$1"; fails=$((fails+1)); }

check_file() {
  if [ -e "$1" ]; then ok "$2"; else bad "$2 ($1 missing)"; fi
}
check_exec() {
  if [ -x "$1" ]; then ok "$2"; else bad "$2 ($1 missing or not executable)"; fi
}

echo "== SketchyBar =="
if command -v sketchybar >/dev/null 2>&1; then
  ok "sketchybar $(sketchybar --version 2>/dev/null | tr -d '\n')"
else
  bad "sketchybar not on PATH"
fi
check_file "$HOME/.config/sketchybar/sketchybarrc" "sketchybarrc"
check_file "$HOME/.config/sketchybar/config.sh" "config.sh"
check_file "$HOME/.config/sketchybar/colors.sh" "colors.sh"
check_exec "$H/2026-11-01-tile-picker" "tile-picker binary"
check_exec "$H/2026-11-01-display-transfer-fast" "display-transfer binary"
check_exec "$H/2026-11-01-tile-picker-run" "tile-picker wrapper"
for d in left right top bottom; do
  check_file "$H/2026-11-01-tile-picker-251-$d.json" "251 config $d"
done

echo "== Picker self-test =="
if [ -x "$H/2026-11-01-tile-picker" ]; then
  if "$H/2026-11-01-tile-picker" --self-test 2>/dev/null | grep -q '"result":"pass"'; then
    ok "geometry + fraction self-test"
  else
    bad "picker self-test did not pass"
  fi
else
  warn "picker binary missing; skipped self-test"
fi

echo "== Launch agents =="
if launchctl list 2>/dev/null | grep -q 'homebrew.mxcl.sketchybar'; then
  ok "SketchyBar LaunchAgent loaded"
else
  warn "SketchyBar LaunchAgent not loaded"
fi
if launchctl list 2>/dev/null | grep -q 'com.local.KeyRemapping'; then
  ok "KeyRemapping LaunchAgent loaded"
else
  warn "KeyRemapping LaunchAgent not loaded"
fi

echo "== Keyboard =="
check_file "$HOME/.config/karabiner/karabiner.json" "karabiner.json"
check_file "$HOME/Library/LaunchAgents/com.local.KeyRemapping.plist" "KeyRemapping plist"
if pgrep -x Karabiner-Elements >/dev/null 2>&1 || launchctl list 2>/dev/null | grep -q 'org.pqrs.service.agent.Karabiner'; then
  ok "Karabiner services running"
else
  warn "Karabiner services not detected"
fi

echo "== Codex / OpenCode =="
check_file "$P/2026-11-01-codex-ready.py" "Codex notify wrapper"
check_file "$P/2026-11-01-task-ready.py" "ready inbox backend"
check_file "$P/2026-11-01-task-ready.sh" "ready badge renderer"
check_file "$HOME/.config/opencode/plugins/2026-11-01-sketchybar-ready.js" "OpenCode plugin"
if grep -qs '2026-11-01-codex-ready.py' "$HOME/.codex/config.toml"; then
  ok "Codex notify references the wrapper"
else
  warn "Codex notify does not reference the wrapper"
fi

echo "== BetterTouchTool =="
if pgrep -x BetterTouchTool >/dev/null 2>&1; then
  ok "BTT running"
  TMP=$(mktemp)
  if osascript -e 'tell application "BetterTouchTool" to get_triggers' > "$TMP" 2>/dev/null; then
    python3 - "$TMP" <<'PY'
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception as exc:
    print("FAIL  could not parse BTT trigger export:", exc)
    raise SystemExit(2)
want = {
    "BA93AD1F-552E-4C50-9D51-A220FE9336CA": "left",
    "0FD4A25B-5995-4996-9881-F3514D7DF5F7": "right",
    "5928C09C-F6E1-4668-9A3F-BF4BC09D997B": "top",
    "288F5F67-9D20-4DD4-9138-3D2B97CED194": "bottom",
}
by = {t.get("BTTUUID"): t for t in data}
bad = 0
for uuid, direction in want.items():
    t = by.get(uuid)
    if not t:
        print(f"FAIL  missing trigger {uuid}")
        bad += 1
        continue
    acts = t.get("BTTActionsToExecute", [])
    if len(acts) == 1 and acts[0].get("BTTPredefinedActionType") == 137 and \
       "tile-picker-run" in acts[0].get("BTTTerminalCommand", "") and \
       direction in acts[0].get("BTTTerminalCommand", ""):
        print(f"OK    {t.get('BTTTriggerTypeDescriptionReadOnly')} -> type 137 wrapper")
    else:
        print(f"FAIL  {t.get('BTTTriggerTypeDescriptionReadOnly')} is not the expected type 137 wrapper")
        bad += 1
raise SystemExit(1 if bad else 0)
PY
    if [ $? -ne 0 ]; then fails=$((fails+1)); fi
  else
    bad "could not read BTT triggers"
  fi
  rm -f "$TMP"
else
  warn "BTT not running; skipped trigger check"
fi

echo "== State =="
if [ -f "$HOME/.cache/sketchybar/2026-11-01-task-ready.sqlite3" ]; then
  sqlite3 "$HOME/.cache/sketchybar/2026-11-01-task-ready.sqlite3" \
    "select source || ': ' || count(*) || ' rows, ' || sum(ack=0) || ' unacked' from ready group by source;" 2>/dev/null \
    | sed 's/^/      /' || true
fi
[ -f "$HOME/.cache/sketchybar/2026-11-01-tile-picker-last.json" ] && \
  echo "      last picker: $(cat "$HOME/.cache/sketchybar/2026-11-01-tile-picker-last.json")"

echo
printf 'Result: %d failure(s), %d warning(s)\n' "$fails" "$warns"
exit "$([ "$fails" -eq 0 ] && echo 0 || echo 1)"
