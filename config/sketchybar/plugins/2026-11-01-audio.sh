#!/bin/bash
source "$CONFIG_DIR/colors.sh"; source "$CONFIG_DIR/plugins/popup.sh"
STATE="$HOME/.cache/sketchybar/2026-11-01-input-volume"
INPUT=$(osascript -e 'input volume of (get volume settings)' 2>/dev/null)
INPUT=${INPUT:-0}
if [ "$1" = mic ]; then
 if [ "$INPUT" -gt 0 ]; then printf '%s' "$INPUT" > "$STATE"; osascript -e 'set volume input volume 0' >/dev/null
 else OLD=$(cat "$STATE" 2>/dev/null); [[ "$OLD" =~ ^[0-9]+$ ]] || OLD=50; osascript -e "set volume input volume $OLD" >/dev/null; fi
 INPUT=$(osascript -e 'input volume of (get volume settings)' 2>/dev/null); INPUT=${INPUT:-0}
fi
OUT=$("$CONFIG_DIR/helper/audio" 2>/dev/null | awk -F'\t' '$4==1{print $2;exit}')
[ -n "$OUT" ] || OUT="Audio"
SHORT="$OUT"; [[ "$OUT" = *MacBook*Speakers* ]] && SHORT=Speakers
[ ${#SHORT} -gt 15 ] && SHORT="${SHORT:0:14}…"
MUTED=$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)
[ "$MUTED" = true ] && SHORT="$SHORT · muted"
sketchybar --set audio label="$SHORT" --set microphone label="$([ "$INPUT" = 0 ] && echo off || echo on)" icon.color=$([ "$INPUT" = 0 ] && echo "$WARN" || echo "$TEXT3")
ACT="@CONFIG_DIR='$CONFIG_DIR' bash '$CONFIG_DIR/plugins/2026-11-01-audio.sh'"
{ printf 'output\t%s\t%s\t\n' "$OUT" "$TEXT"
  printf 'input\t%s%% gain\t%s\t\n' "$INPUT" "$TEXT"
  printf 'mic\t%s\t%s\t%s mic\n' "$([ "$INPUT" = 0 ] && echo 'Restore input level' || echo 'Set input level to zero')" "$TEXT" "$ACT"
  printf 'settings\tAudio devices & volume ↗\t%s\topen "x-apple.systempreferences:com.apple.Sound-Settings.extension"\n' "$TEXT2"
} | POPUP_W=310 popup_rows audio AUDIO
