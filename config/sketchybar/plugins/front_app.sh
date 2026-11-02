#!/bin/bash
# Keep SketchyBar event INFO separate from the palette's INFO colour.
APP_NAME="${INFO:-}"
EVENT="${SENDER:-}"
source "$CONFIG_DIR/colors.sh"
if [ "$EVENT" != front_app_switched ] || [ -z "$APP_NAME" ]; then
 APP_NAME=$(lsappinfo info -only name "$(lsappinfo front)" 2>/dev/null | python3 -c '
import re,sys
s=sys.stdin.read();m=re.search(r"\"LSDisplayName\"\s*=\s*\"([^\"]+)\"",s) or re.search(r"^\"([^\"]+)\"",s)
print(m.group(1) if m else "")')
fi
[ -n "$APP_NAME" ] || exit 0
[ ${#APP_NAME} -gt 25 ] && APP_NAME="${APP_NAME:0:24}…"
sketchybar --set front_app label="$APP_NAME"
