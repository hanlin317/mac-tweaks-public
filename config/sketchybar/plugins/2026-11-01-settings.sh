#!/bin/bash
source "$CONFIG_DIR/colors.sh"; source "$CONFIG_DIR/config.sh"; source "$CONFIG_DIR/plugins/popup.sh"
case "$1" in
 dark|light|auto)
  python3 - "$CONFIG_DIR/2026-11-01-preferences.sh" "$1" <<'PY'
import sys,re
from pathlib import Path
p=Path(sys.argv[1]);s=p.read_text();p.write_text(re.sub(r'^THEME=.*$', 'THEME='+sys.argv[2], s, flags=re.M))
PY
  sketchybar --reload; exit ;;
 events)
  python3 - "$CONFIG_DIR/2026-11-01-preferences.sh" <<'PY'
import sys,re
from pathlib import Path
p=Path(sys.argv[1]);s=p.read_text();m=re.search(r'^CAL_NEXT=(\d)',s,re.M);p.write_text(re.sub(r'^CAL_NEXT=.*$', 'CAL_NEXT='+('0' if m and m[1]=='1' else '1'),s,flags=re.M))
PY
  CONFIG_DIR="$CONFIG_DIR" bash "$CONFIG_DIR/plugins/2026-11-01-calendar.sh"; exit ;;
 calendar-access)
  STATUS=$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1]))["status"])
except (OSError,ValueError,KeyError): print("starting")' "$HOME/.cache/sketchybar/2026-11-01-calendar-data.json")
  if [ "$STATUS" = denied ]; then open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars'
  else open -gj -a "$CONFIG_DIR/helper/2026-11-01-CalendarAccess.app" --args request; fi
  CONFIG_DIR="$CONFIG_DIR" bash "$CONFIG_DIR/plugins/2026-11-01-calendar.sh"; exit ;;
 reload) sketchybar --reload; exit ;;
 config) open -a TextEdit "$CONFIG_DIR/config.sh"; exit ;;
 folder) open "$CONFIG_DIR"; exit ;;
esac
STATUS=$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1]))["status"])
except (OSError,ValueError,KeyError): print("starting")' "$HOME/.cache/sketchybar/2026-11-01-calendar-data.json")
ACT="@CONFIG_DIR='$CONFIG_DIR' bash '$CONFIG_DIR/plugins/2026-11-01-settings.sh'"
{ printf 'theme\tDark\t%s\t%s dark\n' "$TEXT" "$ACT"
  printf 'theme\tLight\t%s\t%s light\n' "$TEXT" "$ACT"
  printf 'theme\tFollow system\t%s\t%s auto\n' "$TEXT" "$ACT"
  printf 'events\t%s\t%s\t%s events\n' "$([ "$CAL_NEXT" = 1 ] && echo 'On — click to disable' || echo 'Off — click to enable')" "$TEXT" "$ACT"
  if [ "$STATUS" = authorized ]; then printf 'calendar\tConnected\t%s\t\n' "$TEXT2"
  else printf 'calendar\tAllow Calendar access\t%s\t%s calendar-access\n' "$TEXT" "$ACT"; fi
  printf 'focus\tStart 25 minutes\t%s\t@CONFIG_DIR="%s" bash "%s/plugins/2026-11-01-focus.sh" start25\n' "$TEXT" "$CONFIG_DIR" "$CONFIG_DIR"
  printf 'focus\tStart 50 minutes\t%s\t@CONFIG_DIR="%s" bash "%s/plugins/2026-11-01-focus.sh" start50\n' "$TEXT" "$CONFIG_DIR" "$CONFIG_DIR"
  printf 'audio\tSound settings ↗\t%s\topen "x-apple.systempreferences:com.apple.Sound-Settings.extension"\n' "$TEXT" 
  printf 'reload\tReload bar\t%s\t%s reload\n' "$TEXT" "$ACT"
  printf 'advanced\tOpen configuration folder ↗\t%s\t%s folder\n' "$TEXT2" "$ACT"
} | POPUP_W=300 popup_rows settings SETTINGS
[ "$1" = open ] && popup_toggle settings
