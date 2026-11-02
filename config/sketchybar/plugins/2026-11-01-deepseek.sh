#!/bin/bash
source "$CONFIG_DIR/colors.sh"; source "$CONFIG_DIR/config.sh"; source "$CONFIG_DIR/plugins/popup.sh"
J=$(python3 "$CONFIG_DIR/plugins/2026-11-01-deepseek-balance.py")
LABEL=$(python3 -c 'import json,sys;print(json.load(sys.stdin)["label"])' <<<"$J")
LEVEL=$(python3 -c 'import json,sys,decimal
x=json.load(sys.stdin);level=0
if x.get("error"):level=1
for k,v in x.get("rows",[]):
 if k!="left":continue
 currency,amount=v.split();n=decimal.Decimal(amount)
 if currency=="USD" and n==0:continue
 low=decimal.Decimal(sys.argv[1] if currency=="CNY" else sys.argv[3]);critical=decimal.Decimal(sys.argv[2] if currency=="CNY" else sys.argv[4])
 if n<low:level=max(level,1)
 if n<critical:level=2
print(level)' "$DEEPSEEK_LOW_CNY" "$DEEPSEEK_CRITICAL_CNY" "$DEEPSEEK_LOW_USD" "$DEEPSEEK_CRITICAL_USD" <<<"$J")
COLOR=$TEXT; [ "$LEVEL" = 1 ] && COLOR=$WARN; [ "$LEVEL" = 2 ] && COLOR=$ERR
anim_label deepseek "${LABEL:-—}" label.color=$COLOR
python3 -c 'import json,sys
for k,v in json.load(sys.stdin)["rows"]:print(k+"\t"+v+"\t"+sys.argv[1]+"\t")' "$TEXT" <<<"$J" | POPUP_W=390 popup_rows deepseek DEEPSEEK
