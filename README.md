# mac-tweaks-public

A sanitized reference for a macOS **SketchyBar + BetterTouchTool + Karabiner** setup.
It documents the architecture, gestures, helpers, permissions and restore steps, and includes the
editable configuration sources. Personal paths, app names and credentials are removed.

- Host: macOS 27.2, arm64
- SketchyBar: 2.24.0
- BetterTouchTool: 6.990
- Karabiner-Elements: installed
- Displays: MacBook 1800×1169 and external 2560×1440

Paths in the docs use `$HOME`. BTT commands in the example JSON use `/Users/yourname`; replace that
with your own home directory before applying them.

## Features

| Area | Highlights | Docs |
|---|---|---|
| SketchyBar | Notch/island bar, popups, media/audio/wifi/calendar, focus timer, Codex usage | [docs/01-sketchybar.md](docs/01-sketchybar.md) |
| BetterTouchTool | Display swipes, half/third/full tiling, companion picker, width cycling | [docs/02-btt.md](docs/02-btt.md) |
| Window management | Exact geometry, picker, cycle rules, display transfer | [docs/03-window-management.md](docs/03-window-management.md) |
| Task badges | Codex notify hook + OpenCode v2 plugin → bar-only badges | [docs/04-task-ready.md](docs/04-task-ready.md) |
| Keyboard | Karabiner Caps-Lock nav + hidutil remap | [docs/05-keyboard.md](docs/05-keyboard.md) |
| Shell/terminal | fish config and terminal notes | [docs/06-shell-terminal.md](docs/06-shell-terminal.md) |
| Launch agents | SketchyBar and key-remapping agents | [docs/07-launch-agents.md](docs/07-launch-agents.md) |
| Restore | Rebuild on a fresh Mac | [docs/08-install-restore.md](docs/08-install-restore.md) |
| Troubleshooting | Symptom → cause → fix | [docs/09-troubleshooting.md](docs/09-troubleshooting.md) |
| Changelog | Changes and known limits | [docs/10-changelog.md](docs/10-changelog.md) |

## Gestures

| Gesture | Behaviour |
|---|---|
| 4-finger swipe left / right | Move the focused window to the previous/next display, exact rect |
| Corner click top-left | Left half; if already docked left, cycle 1/2 → 2/3 → 1/3 |
| Corner click top-right | Right half; if already docked right, cycle 1/2 → 2/3 → 1/3 |
| 1-finger tap left edge middle | Top half + companion picker |
| 1-finger tap right edge middle | Bottom half + companion picker |
| Corner force-click bottom-left / bottom-right | Left/right third |
| 1-finger tap bottom middle | Left third |
| 1-finger tap top middle | Full work area |

The picker appears after a normal half and fills the opposite half with the selected window.
Width cycling shows no panel.

## Layout

```
config/sketchybar/   bar config, plugins, helper sources, saved 251 configs
config/btt/          half-gesture map, saved 251 configs, socket/version notes
config/keyboard/     karabiner.json + KeyRemapping plist
config/opencode/     task-ready plugin only
config/codex/        notify wrapper + template
config/shell/        fish config
config/launchagents/ SketchyBar and KeyRemapping plists
scripts/             build helpers, verify, snapshot BTT, test tools
docs/                guides
```

## Important facts

- The SketchyBar config is based on **sketchybar-island** by garamnoh (MIT). See
  [config/sketchybar/LICENSE](config/sketchybar/LICENSE) and
  [config/sketchybar/UPSTREAM-README.md](config/sketchybar/UPSTREAM-README.md).
- Helpers are Swift sources only; build with `scripts/build-helpers.sh`.
- BTT 6.990 does not persist **appended** actions across a restart. The half gestures replace an
  existing action with type 137 instead. See [docs/02-btt.md](docs/02-btt.md).
- Replacing a compiled helper with `cp -p` can carry a stale `com.apple.macl` xattr and macOS
  SIGKILLs the new binary (exit 137). Install with `cat`, `chmod`, `xattr -c`.
- No credentials are included. The public repo omits service files, API keys, tokens, keychains,
  app databases and personal Raycast commands.

## Attribution

- SketchyBar by Felix Kratz (GPL-3.0): https://github.com/FelixKratz/SketchyBar
- sketchybar-island by garamnoh (MIT): https://github.com/garamnohhh/sketchybar-island
- BetterTouchTool: https://folivora.ai
- Karabiner-Elements: https://karabiner-elements.pqrs.org
