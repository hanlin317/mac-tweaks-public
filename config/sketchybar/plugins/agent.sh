#!/bin/bash
# Codex-only usage from local session records. Unknown data stays unavailable.
source "$CONFIG_DIR/colors.sh"; source "$CONFIG_DIR/config.sh"; source "$CONFIG_DIR/plugins/popup.sh"
IFS=$'\t' read -r FIVE WEEK RESET5 RESETW <<<"$(python3 "$CONFIG_DIR/plugins/usage.py" | python3 -c '
import json,sys,datetime as D
x=json.load(sys.stdin).get("codex",{})
def pct(v): return "—" if v is None else str(max(0,min(100,100-v)))+"% left"
def reset(t):
 try: return D.datetime.fromisoformat(t).astimezone().strftime("%a %H:%M")
 except Exception: return "unavailable"
print("\t".join([pct(x.get("five")),pct(x.get("week")),reset(x.get("fiveResetsAt")),reset(x.get("weekResetsAt"))]))
')"
remaining_color() {
 local left="${1%%\%*}"
 if [[ "$left" =~ ^[0-9]+$ ]]; then
  if [ "$left" -lt 10 ]; then printf '%s' "$ERR"; return; fi
  if [ "$left" -lt 20 ]; then printf '%s' "$WARN"; return; fi
 fi
 printf '%s' "$TEXT"
}
COLOR=$(remaining_color "$FIVE")
WEEK_COLOR=$(remaining_color "$WEEK")
anim_label agent.codex "${FIVE:-—}" label.color=$COLOR
{ printf '5-hour\t%s\t%s\t\n' "${FIVE:-—}" "$COLOR"
  printf 'Resets\t%s\t%s\t\n' "${RESET5:-unavailable}" "$TEXT2"
  printf 'Weekly\t%s\t%s\t\n' "${WEEK:-—}" "$WEEK_COLOR"
  printf 'Resets\t%s\t%s\t\n' "${RESETW:-unavailable}" "$TEXT2"
  printf '_\tLocal Codex limits\t%s\t\n' "$TEXT3"
  printf '_\tChatGPT usage not included\t%s\t\n' "$TEXT3"
} | POPUP_W=300 POPUP_KW=96 popup_rows agent CODEX
