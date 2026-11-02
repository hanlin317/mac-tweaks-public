#!/bin/bash
source "$CONFIG_DIR/colors.sh"; source "$CONFIG_DIR/plugins/popup.sh"
J=$(python3 "$CONFIG_DIR/plugins/2026-11-01-focus-state.py" "${1:-tick}")
IFS=$'\t' read -r LABEL MODE <<<"$(python3 -c 'import json,sys;x=json.load(sys.stdin);print(x["label"]+"\t"+x["mode"])' <<<"$J")"
COLOR=$TEXT; [ "$MODE" = running ] && COLOR=$ACCENT; [ "$MODE" = done ] && COLOR=$WARN
# Tick every second only while the timer runs; idle otherwise.
WANT=30; [ "$MODE" = running ] && WANT=1
sketchybar --set focus update_freq=$WANT
sketchybar --set focus label="$LABEL" label.color=$COLOR
ACT="@CONFIG_DIR='$CONFIG_DIR' bash '$CONFIG_DIR/plugins/2026-11-01-focus.sh'"
{ printf 'start\t25 minutes\t%s\t%s start25\n' "$TEXT" "$ACT"
  printf 'start\t50 minutes\t%s\t%s start50\n' "$TEXT" "$ACT"
  if [ "$MODE" = running ]; then printf 'pause\tPause timer\t%s\t%s pause\n' "$TEXT" "$ACT"
  elif [ "$MODE" = paused ]; then printf 'resume\tResume timer\t%s\t%s resume\n' "$TEXT" "$ACT"
  else printf '~\t.\t\t\n'; fi
  printf 'reset\tReset timer\t%s\t%s reset\n' "$TEXT2" "$ACT"
} | POPUP_W=220 popup_rows focus FOCUS
