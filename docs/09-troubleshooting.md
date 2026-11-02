# Troubleshooting

## Window tiling / picker

| Symptom | Likely cause | Fix |
|---|---|---|
| Halfing still works, panel never appears | BTT lost the type-137 actions after an update | Run `scripts/verify.sh`; re-apply the four actions ([02-btt.md](02-btt.md#re-apply-the-half-actions)); quit/relaunch BTT and verify |
| Panel appears, chosen window does not move | No Accessibility for BTT; app refuses AX and 446 | Check BTT Accessibility; inspect `~/.cache/sketchybar/2026-11-01-tile-picker-last.json` for `method`/`final` |
| Second same-corner click halves instead of cycling | Window not full height or not anchored within 8 pt | Cycling requires a full-height half/2-3/1-3 window; resize it back to full height |
| Cycle order feels wrong | Fixed at 1/2 → 2/3 → 1/3 | Change `FRACTIONS`/`nextFraction` in `2026-11-01-tile-picker.swift` and rebuild |
| Panels stack | Old pre-lock binary | Confirm the installed binary has the single-instance lock; two launches must leave one process |
| Picker starts but exits `137` | Stale `com.apple.macl` xattr after replacing the binary | `cat new > helper`, `chmod 755`, `xattr -c`, optionally `codesign --force --sign -` |
| Click selection does nothing | Click path not exercised in the automated tests | Use keyboard first; if click still fails, check the table's `action` target in the picker source |

## Display transfer

| Symptom | Cause | Fix |
|---|---|---|
| Swipe takes ~300–400 ms | BTT socket not enabled, AppleScript fallback | Enable BTT socket; check `/tmp/com.hegenberg.BetterTouchTool.sock` |
| Window lands at 1286 height instead of 1392 | Single 251 clamps to destination visible frame | Use the 446 helper; do not switch back to one 251 |
| Visible two-step | 251→446 sequence | Use one 446 action |
| Nothing happens on a full-screen window | Native full-screen is intentionally skipped | Exit native full-screen first |

## Task badges

| Symptom | Cause | Fix |
|---|---|---|
| Codex badge never appears | Codex rewrote `notify`; hook not chained | Check `~/.codex/config.toml` and `~/.cache/sketchybar/2026-11-01-codex-notify.log` |
| OpenCode badge never appears | v1 plugin rejected, or event names changed | Check OpenCode log for plugin load errors; use v2 `session.execution.succeeded` |
| Duplicate OpenCode counts | Hot-reloaded plugin instances | Restart the OpenCode server cleanly |
| Badge stays visible after switching apps | Auto-clear failing | Frontmost bundle must be `com.openai.codex` / `ai.opencode.desktop`; run the badge script manually |
| Badge count flashes stale | Label not cleared when hidden | Current `task-ready.sh` clears the label; verify it is the installed version |

## Bar

| Symptom | Cause | Fix |
|---|---|---|
| Bar blank / items missing | Helper binary missing or not executable | Build with `scripts/build-helpers.sh`, install binaries, `chmod 755` |
| Focus word sits too high/low | Glyph fallback font; label offset | Icon `y_offset=3`; label `0`; adjust and reload |
| Bar turns opaque after wake/display change | Blur on macOS 27 | `BAR_BLUR=0` |
| Clock shows stale time | Timer interval | `clock` is 10 s; click to open ItsyCal or lower `update_freq` |
| Popup rows stale | Generated popup cache | `rm -f ~/.cache/sketchybar/popup.*`, reload |

## Keyboard

| Symptom | Cause | Fix |
|---|---|---|
| Caps Lock does not act as Escape | Karabiner not running / profile not selected | Open Karabiner-Elements; confirm profile and rule enabled |
| A key is remapped twice | Karabiner + hidutil both active | Check `hidutil property --get UserKeyMapping` and the Karabiner rule |
| Key remap lost after reboot | LaunchAgent not loaded | `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.KeyRemapping.plist` |

## BTT persistence

BTT 6.990 has a specific trap: `update_trigger` can add an action in memory, but the action
disappears after a graceful quit/relaunch. Changing an existing action persists. Always verify with:

```bash
osascript -e 'tell application "BetterTouchTool" to get_triggers' | \
  python3 -c 'import json,sys; d=json.load(sys.stdin); print(sum(1 for t in d for a in t.get("BTTActionsToExecute",[]) if a.get("BTTPredefinedActionType")==137))'
```

Expected: `4`.

## Useful checks

```bash
scripts/verify.sh
~/.config/sketchybar/helper/2026-11-01-tile-picker --self-test
tail ~/.cache/sketchybar/2026-11-01-tile-picker-starts.log
tail ~/.cache/sketchybar/2026-11-01-codex-notify.log
sqlite3 ~/.cache/sketchybar/2026-11-01-task-ready.sqlite3 \
  "select source, count(*), sum(ack=0) from ready group by source"
```
