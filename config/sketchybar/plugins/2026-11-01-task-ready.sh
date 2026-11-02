#!/bin/bash
source "$CONFIG_DIR/colors.sh"
BRIDGE="$CONFIG_DIR/plugins/2026-11-01-task-ready.py"
PY=/opt/homebrew/bin/python3
if [ "${1:-}" = ack ]; then "$PY" "$BRIDGE" ack "$2" || exit; fi

# Opening — or already being in — the app that finished clears its own badge.
FRONT=$(lsappinfo front 2>/dev/null)
BUNDLE=""
[ -n "$FRONT" ] && BUNDLE=$(lsappinfo info -only bundleID "$FRONT" 2>/dev/null | sed -n 's/.*bundleID="\([^"]*\)".*/\1/p')
case "$BUNDLE" in
  com.openai.codex)    "$PY" "$BRIDGE" ack codex ;;
  ai.opencode.desktop) "$PY" "$BRIDGE" ack opencode ;;
esac

STATE=$("$PY" "$BRIDGE" status) || exit
while IFS=$'\t' read -r SOURCE COUNT; do
  TITLE=Codex; [ "$SOURCE" = opencode ] && TITLE=OpenCode
  LABEL="$TITLE ready"; [ "$COUNT" -gt 1 ] && LABEL="$TITLE ready ($COUNT)"
  if [ "$COUNT" -gt 0 ]; then
    sketchybar --set "ready.$SOURCE" drawing=on label="$LABEL" label.color="$ACCENT"
  else
    sketchybar --set "ready.$SOURCE" drawing=off label=""
  fi
done < <("$PY" -c 'import json,sys;d=json.load(sys.stdin);[print(k+"\t"+str(d[k])) for k in ("codex","opencode")]' <<<"$STATE")
