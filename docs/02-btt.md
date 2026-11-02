# BetterTouchTool

## Version and transport

- BTT **6.990** (the setup was originally built on 6.455).
- BTT socket server enabled: `Settings → Scripting BTT → Command Line → Enable BTT Socket Server For Command Line Usage`.
- Socket: `/tmp/com.hegenberg.BetterTouchTool.sock`
- CLI: `/Applications/BetterTouchTool.app/Contents/SharedSupport/bin/bttcli`
- Gesture map: [`config/btt/half-gestures.json`](../config/btt/half-gestures.json)

The full BTT SQLite data store is not copied (proprietary database, account/licence data).
The JSON export is the portable record.

## Gestures

| Gesture | Scope | Action | Result |
|---|---|---|---|
| 4-finger swipe left | Global | 246 → `2026-11-01-display-transfer-fast left` | Focused window to previous display |
| 4-finger swipe right | Global | 246 → `2026-11-01-display-transfer-fast right` | Focused window to next display |
| Corner click top-left | Global | 137 → `2026-11-01-tile-picker-run left` | Left half, picker, or width cycle |
| Corner click top-right | Global | 137 → `2026-11-01-tile-picker-run right` | Right half, picker, or width cycle |
| 1-finger tap left edge middle | Global | 137 → `...-run top` | Top half + picker |
| 1-finger tap right edge middle | Global | 137 → `...-run bottom` | Bottom half + picker |
| Corner force-click bottom-left | Global | 251 | Left third |
| Corner force-click bottom-right | Global | 251 | Right third |
| 1-finger tap bottom middle | Global | 251 | Left third |
| 1-finger tap top middle | Global | 251 | Full work area |
| 2-finger swipe right | Obsidian | 264 → Cmd+Opt+Left | App-specific navigation |
| 2-finger swipe left | Obsidian | 264 → Cmd+Opt+Right | App-specific navigation |

Trigger UUIDs:

```
4 Finger Swipe Left             658954D7-D243-4AC0-83A1-7CFE58A7FC94
4 Finger Swipe Right            71EFCE54-2A6F-4836-9317-0827BECA0C20
Corner Click Top Left           BA93AD1F-552E-4C50-9D51-A220FE9336CA
Corner Click Top Right          0FD4A25B-5995-4996-9881-F3514D7DF5F7
1 Finger Tap Left Side Middle   5928C09C-F6E1-4668-9A3F-BF4BC09D997B
1 Finger Tap Right Side Middle  288F5F67-9D20-4DD4-9138-3D2B97CED194
Corner FORCE Click Bottom Left  2ABDAF08-617B-4FA7-A27C-AC78A5AAD310
Corner FORCE Click Bottom Right E996EC18-E8BE-4FE9-8F08-7E6F8524E1B9
1 Finger Tap Bottom Middle      EB651DEA-8785-4B26-859B-CD190EB293D7
1 Finger Tap Top Middle         630E9E1B-7E30-4CA6-A92B-B365B4AB3994
```

Half-gesture action UUIDs (the existing actions that were changed to type 137):

```
Corner Click Top Left           90FE0AFA-1D7D-4A02-B15B-B4E9324E06DD
Corner Click Top Right          27161342-0511-4D4E-BF5D-E96239F3F9E7
1 Finger Tap Left Side Middle   54569508-0D83-40F3-83EF-911351EED773
1 Finger Tap Right Side Middle  C89DE382-1DA3-4B00-9C7A-47D1D83402DC
```

## Action types used

| Type | Name | Use |
|---|---|---|
| 137 | Execute Terminal Command (Background) | Launches the tile-picker wrapper without blocking BTT |
| 246 | Execute Terminal Command (Synchronous, blocking) | Display transfer; the helper exits in ~300–400 ms |
| 251 | Move or Resize Window to Custom Position and Size | Thirds, full work area, original half configs |
| 446 | Generic move + size action (`x,y,w,h`) | Exact rect used by the helper/picker |
| 264 | Send keyboard shortcut | Obsidian 2-finger swipes |

`bttcli trigger_action` accepts a JSON action without adding it to the BTT UI. The helper uses this
for the 446 dispatches.

## Half gesture wiring (current)

Each half gesture is **one type-137 action**:

```json
{
  "BTTPredefinedActionType": 137,
  "BTTTerminalCommand": "/bin/bash /Users/yourname/.config/sketchybar/helper/2026-11-01-tile-picker-run left"
}
```

The wrapper:

1. dispatches the user's original 251 half from
   `config/sketchybar/helper/2026-11-01-tile-picker-251-<dir>.json`;
2. runs `2026-11-01-tile-picker <dir> --already`.

This keeps the half independent of the picker. If the picker fails, the 251 already did the half.
If the 251 dispatch fails, the picker's `--already` wait expires and it tiles with 446/AX itself.

The wrapper is also where width cycling is decided for left/right: if the active window is already
docked to that side, it cycles and exits before the 251.

## Why the half actions were replaced, not appended

BTT 6.990 **does not persist an appended action** created with `update_trigger` across a graceful
restart. This was reproduced twice:

1. minimal fields;
2. with `BTTTriggerBelongsToPreset` and `BTTLastUpdatedAt`.

Both times the appended 137 action disappeared after quit/relaunch. Changing the type and command of
an **existing** action does persist — that is how the display-swipe actions survived the 6.455 to
6.990 update.

The working implementation therefore replaces the 251 action in each half trigger with a 137
action. The original 251 configurations are saved in the repo so they can be restored.

## Re-apply the half actions

The source of truth is `config/btt/half-gestures.json` in this repo (or the plan in the history).
The actions are applied by UUID, not by deleting/recreating triggers.

```applescript
on run argv
  tell application "BetterTouchTool"
    return update_trigger (item 1 of argv) json (item 2 of argv)
  end tell
end run
```

For each action UUID:

```bash
osascript update-trigger.applescript <action-uuid> \
  '{"BTTPredefinedActionType":137,"BTTTerminalCommand":"/bin/bash /Users/yourname/.config/sketchybar/helper/2026-11-01-tile-picker-run left"}'
```

Then:

1. quit BTT gracefully;
2. relaunch;
3. read back the four actions and confirm they are still type 137 with the wrapper command.

`scripts/verify.sh` does the readback check.

## Restoring the original 251 behaviour

The saved 251 configs are in `config/sketchybar/helper/2026-11-01-tile-picker-251-*.json` and
`config/btt/2026-11-01-tile-picker-251-*.json`. To go back to plain halfing, update each half action
to type 251 with the `BTTActionMoveResizeConfig` from the matching file. The picker is then no
longer involved.

## Display transfer

The 4-finger swipes are type 246 and call the display-transfer helper. The helper:

- reads the focused window with public CoreGraphics/AppKit APIs;
- plans against both displays;
- dispatches **one** BTT 446 with the exact target rect;
- verifies through `CGWindowList`;
- corrects with a public AX position-then-size write only if needed;
- skips native full-screen spaces.

See [03-window-management.md](03-window-management.md).

## Notes

- BTT updates are the main risk to persistence. After any BTT update, run `scripts/verify.sh`.
- The example commands use `/Users/yourname`; replace it with your home directory when applying.
- The socket must be enabled for the fast helper path; the helper falls back to AppleScript if the
  socket is missing (slower).
- Type 137 runs in the background, so a picker panel can stay open without blocking the next
  gesture. A newer gesture takes over via the picker's single-instance lock.
