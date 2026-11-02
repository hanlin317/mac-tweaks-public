#!/bin/bash
# Media island. [ EQ  app  title   «  ❚❚  » ] — every 2 s, and right after a control is pressed
source "$CONFIG_DIR/colors.sh"; source "$CONFIG_DIR/config.sh"; source "$CONFIG_DIR/plugins/popup.sh"
case "$SENDER" in   # control hover: --text-3 → --text (left as is when nothing is playing — it cannot be pressed)
  mouse.entered) [ "$(cut -f1 "$HOME/.cache/sketchybar/media_state" 2>/dev/null)" = none ] || sketchybar --set "$NAME" label.color=$TEXT; exit 0 ;;
  mouse.exited)  [ "$(cut -f1 "$HOME/.cache/sketchybar/media_state" 2>/dev/null)" = none ] || sketchybar --set "$NAME" label.color=$TEXT3; exit 0 ;;
esac
P="$CONFIG_DIR/plugins"; LAST="$HOME/.cache/sketchybar/media_last"
NOTCH_L=$(cat "$HOME/.cache/sketchybar/notch_l" 2>/dev/null || echo 785)   # right end of the media island = notch left − 5 (sketchybarrc measures it with helper/notch and writes it here)
fill() {
  python3 "$CONFIG_DIR/plugins/2026-11-01-multidisplay-layout.py" "$1" "$2"
}

[ "$SENDER" = media_layout ] && { IFS=$'\t' read -r _ a t _ <<<"$(cat "$HOME/.cache/sketchybar/media_shown" 2>/dev/null)"; fill "${a:-media}" "${t:-—}"; exit 0; }
IFS=$'\t' read -r S APP TITLE ARTIST EL DUR SRC <<<"$("$P/media_src.sh")"
echo "$S" > "$HOME/.cache/sketchybar/media_state"
t() { [ -n "$1" ] && printf '%d:%02d' $(( $1 / 60 )) $(( $1 % 60 )); }
CTL="$P/media_ctl.sh"
if [ "$S" = none ]; then
  IFS=$'\t' read -r _ LAPP LTITLE _ <<<"$(cat "$LAST" 2>/dev/null)"
  pkill -f "$P/eq.sh"; sketchybar --set media update_freq=5   # nothing playing: hide the fill (fill). The 5 s poll covers what the stream misses (playback started in the app)
  printf 'x\tmedia\t—\t\n' > "$HOME/.cache/sketchybar/media_shown"; fill media "—"
  a=(--set media icon=media icon.color=$TEXT3 label.color=$TEXT
     --set media.play label="▶" label.y_offset=0 label.color=$([ -n "$LAPP" ] && echo $TEXT3 || echo $LINE) click_script="$([ -n "$LAPP" ] && echo "$CTL toggle")"
     --set media.prev label.color=$LINE click_script="" --set media.next label.color=$LINE click_script="")
  for i in 1 2 3; do a+=(--set media.eq.$i background.color=$LINE background.height=2 background.y_offset=-4); done
  sketchybar "${a[@]}"
  # with no last-played record (first run, or record cleared) last·app show — and the 'Resume' row is left out — so the wrong app (Apple Music) is not opened
  { printf 'last\t%s\t%s\t\napp\t%s\t%s\t\n' "${LTITLE:-—}" "$TEXT2" "${LAPP:-—}" "$TEXT2"
    [ -n "$LAPP" ] && printf '▶\tResume\t%s\t%s\n' "$TEXT" "$CTL toggle"
    for k in 1 2 3 4 5 6 7 8 9; do printf '~\t.\t\t\n'; done; } | head -n 9 | perl "$P/fit.pl" 170 | POPUP_W=262 popup_rows media MEDIA   # row count fixed at 9 (so rows do not vanish if it changes while open)
  sketchybar --set media.p.2 icon.y_offset=-1 icon.padding_left=13 2>/dev/null   # ▶ Resume row: same correction as the control row above
  for k in 0 1 2; do sketchybar --set media.p.$k background.height=24 background.image.drawing=off background.color=0x00000000 label.drawing=on label.font="$FONT:Regular:12.0" 2>/dev/null; done
  exit 0
fi
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$S" "$APP" "$TITLE" "$ARTIST" "$EL" "$DUR" "$SRC" > "$LAST"
# app name = caption color (--text-3, same as the port·wifi captions) · title = value color (--text). Same for playing, paused and none (2026-10-01)
AC=$TEXT3; TC=$TEXT
if [ "$S" = playing ]; then PL="❚❚"; PW="Pause"; CC=$TEXT2   # controls --text-2
  pgrep -f "$P/eq.sh" >/dev/null || (nohup "$P/eq.sh" >/dev/null 2>&1 &)
  for i in 1 2 3; do sketchybar --set media.eq.$i background.color=$ACCENT; done
else PL="▶"; PW="Play"; CC=$TEXT3
  pkill -f "$P/eq.sh"
  for i in 1 2 3; do sketchybar --set media.eq.$i background.color=$TEXT3 background.height=2 background.y_offset=-4; done
fi
R=0; [ "${DUR:-0}" -gt 0 ] 2>/dev/null && R=$(( ${EL:-0} * 1000 / DUR )); [ $R -gt 1000 ] && R=1000
echo "$R" > "$HOME/.cache/sketchybar/media_ratio"   # progress fill ratio (‰) — drawn by fill
printf 'x\t%s\t%s\t\n' "$APP" "$TITLE" > "$HOME/.cache/sketchybar/media_shown"; fill "$APP" "$TITLE"
# the caption sits on the cell background (--line), so one step brighter (--text-2)
sketchybar --set media icon="$APP" icon.color=$AC label.color=$TC \
  --set media.play label="$PL" label.y_offset=$([ "$PL" = "▶" ] && echo 0 || echo 1) label.color=$CC click_script="$CTL toggle" \
  --set media.prev label.color=$CC click_script="$CTL prev" --set media.next label.color=$CC click_script="$CTL next"
[ "$S" = playing ] && sketchybar --set media update_freq=2 || sketchybar --set media update_freq=5   # playing 2 s · paused 5 s (stream backstop)
OPEN="open -a '$APP'"; [ "$SRC" = music ] && OPEN="open -a Music"
# popup: album art 238 · title · artist · time (position --text-2 / length --text-3) · 40-cell gauge · controls · open
LIVE=0; [ "${DUR:-0}" -gt 0 ] 2>/dev/null || LIVE=1
{ printf '_\t.\t\t\n_\t%s\t%s\t\n_\t%s\t%s\t\n' "$TITLE" "$TEXT" "${ARTIST:-—}" "$TEXT2"
  if [ $LIVE = 1 ]; then printf '_\tlive\t%s\t\n~\t.\t\t\n' "$ERR"; else printf '_\t.\t\t\n_\t.\t\t\n'; fi
  printf '«\tPrevious\t%s\t@%s\n%s\t%s\t%s\t@%s\n»\tNext\t%s\t@%s\nopen\t%s ↗\t%s\t%s\n' "$TEXT" "$CTL prev" "$PL" "$PW" "$TEXT" "$CTL toggle" "$TEXT" "$CTL next" "$APP" "$TEXT2" "$OPEN"
} | perl "$P/fit.pl" 230 | POPUP_W=262 popup_rows media MEDIA
# alignment of the control and open rows (left-cell glyph ↔ text). The popup draws left-cell text 1pt above the value text (measured on the volume popup's key cell).
#   vertical: « » ❚❚ glyphs sit 1pt lower than Hangul on their own (center 3.2~3.4 vs 4.4, 12pt) so they line up as is · ▶ and the 'open' key are lowered 1pt (values measured with the original Hangul labels)
#   horizontal: glyph left bearing ▶ 0 · ❚❚ 2.0 · « » 0.4 · Hangul key 0.6 → ▶ 13 · ❚❚ 11 line up the start
PY=-1; PX=13; [ "$PL" = "❚❚" ] && { PY=0; PX=11; }
# the text (Previous · Play/Pause · Next) looked higher than the icons, so it is lowered 1pt (confirmed by the user, 2026-10-01)
sketchybar --set media.p.5 icon.y_offset=0 icon.padding_left=12 label.y_offset=-1 --set media.p.6 icon.y_offset=$PY icon.padding_left=$PX label.y_offset=-1 \
  --set media.p.7 icon.y_offset=0 icon.padding_left=12 label.y_offset=-1 --set media.p.8 icon.y_offset=-1 icon.padding_left=12 2>/dev/null
ART=$(cat "$HOME/.cache/sketchybar/art.path" 2>/dev/null)   # media_src.sh saves it under a different name per track
if [ -s "$ART" ]; then   # art: scaled down to the 238 cell
  PH=$(sips -g pixelHeight "$ART" 2>/dev/null | awk '/pixelHeight/{print $2}'); SC=$(python3 -c "print(round(238/${PH:-238},4))")
  sketchybar --set media.p.0 background.drawing=on background.color=0x00000000 background.height=238 background.image="$ART" \
    background.image.drawing=on background.image.scale=$SC label.drawing=off icon.drawing=off width=238 padding_left=12 padding_right=12 2>/dev/null
else
  sketchybar --set media.p.0 background.drawing=on background.color=$BG2 background.height=238 background.image.drawing=off \
    label="ALBUM ART" label.font="$FONT:Regular:11.0" label.color=$TEXT2 width=238 padding_left=12 padding_right=12 2>/dev/null
fi
if [ $LIVE = 0 ]; then
  # time row: icon = position (--text-2), label = length (--text-3) right-aligned → matches the gauge end (238)
  n=$(( (${EL:-0} * 40 + DUR / 2) / DUR )); [ $n -gt 40 ] && n=40; f=""; e=""
  for ((i=0;i<40;i++)); do [ $i -lt $n ] && f+="▋" || e+="▋"; done
  bp=0; [ -n "$f" ] && [ -n "$e" ] && bp=1
  # right end of the length text = right end of the last gauge cell (12 + 233.8 + bp, measured ink of Menlo 9.8 '▋'×40). Fixed-width right alignment gets pushed
  # inwards by label.padding → compute the leading padding instead: gauge end + right bearing of the digits (~0.9) − 12 − position width − length width
  TP=$(t "${EL:-0}"); TD=$(t "$DUR")
  sketchybar --set media.p.3 icon.drawing=on icon="$TP" icon.color=$TEXT2 icon.width=dynamic icon.padding_left=12 icon.padding_right=0 \
    label="$TD" label.color=$TEXT3 label.width=dynamic label.align=left \
    label.padding_left=$(( 235 + bp - $(perl "$P/width.pl" "$TP") - $(perl "$P/width.pl" "$TD") )) 2>/dev/null
  sketchybar --set media.p.4 icon.drawing=on icon="$f" icon.color=$TEXT icon.width=dynamic icon.padding_left=12 icon.padding_right=0 \
    icon.font="Menlo:Regular:9.8" label="$e" label.color=$LINE label.font="Menlo:Regular:9.8" label.padding_left=$bp background.height=16 2>/dev/null
fi
