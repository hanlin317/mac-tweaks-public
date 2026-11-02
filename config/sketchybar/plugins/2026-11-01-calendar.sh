#!/bin/bash
source "$CONFIG_DIR/colors.sh"; source "$CONFIG_DIR/config.sh"; source "$CONFIG_DIR/plugins/popup.sh"
[ "${CAL_NEXT:-1}" = 1 ] || { sketchybar --set cal drawing=off; exit 0; }
open -gj -a "$CONFIG_DIR/helper/2026-11-01-CalendarAccess.app" --args refresh
DATA="$HOME/.cache/sketchybar/2026-11-01-calendar-data.json"
J=$(cat "$DATA" 2>/dev/null); [ -n "$J" ] || J='{"status":"starting","events":[]}' 
IFS=$'\t' read -r STATUS LABEL <<<"$(python3 -c 'import json,sys,time,math
x=json.load(sys.stdin);status=x.get("status");events=x.get("events",[]);label=""
if events:
 e=events[0];mins=math.ceil((e["start"]-time.time())/60)
 if mins<=int(sys.argv[1]):label=(e["title"][:23]+("…" if len(e["title"])>23 else ""))+ (" · now" if mins<=0 else " · "+str(mins)+"m")
print(str(status)+"\t"+label)' "${CAL_WINDOW_MIN:-60}" <<<"$J")"
if [ "$STATUS" = starting ]; then
 sketchybar --set cal drawing=off
elif [ "$STATUS" != authorized ]; then
 sketchybar --set cal drawing=on label="Calendar access" label.color=$TEXT3 click_script="CONFIG_DIR='$CONFIG_DIR' '$CONFIG_DIR/plugins/2026-11-01-settings.sh' calendar-access"
else
 sketchybar --set cal drawing=$([ -n "$LABEL" ] && echo on || echo off) label="$LABEL" label.color=$TEXT2 click_script="open 'itsycal://date/now'"
fi
