# Overview

## Host

| Item | Value |
|---|---|
| macOS | 27.2 (26B123) |
| Architecture | arm64 |
| SketchyBar | 2.24.0, Homebrew service `homebrew.mxcl.sketchybar` |
| BetterTouchTool | 6.990 |
| Karabiner-Elements | installed, core service running |
| Shell | zsh login shell; fish config present |
| Displays | MacBook `0,0,1800×1169`; external `-2560,-160,2560×1440` |

Work areas used by the tiling code:

- MacBook visible: `0,0,1800×1129`; tiling work area `5,43,1790×1121`
- External: `-2560,-160,2560×1440`; tiling work area `-2555,-117,2550×1392`

The tiling work area is the display bounds inset by 5 pt on the sides and bottom, 43 pt on top,
and 5 pt between paired windows.

## Data flow

```
BTT gesture
  ├─ display swipe (type 246) → 2026-11-01-display-transfer-fast left|right
  └─ half gesture (type 137)  → 2026-11-01-tile-picker-run <dir>
                                  ├─ dispatch saved BTT 251 (original half)
                                  └─ tile-picker <dir> --already
                                       ├─ picker panel → chosen window to opposite half
                                       └─ left/right docked → cycle width, no panel
```

```
Codex turn ends
  → ~/.codex/config.toml notify
  → SkyComputerUseClient turn-ended --previous-notify [codex-ready.py]
  → codex-ready.py detects SkyComputerUse ancestor (no forward) or forwards
  → task-ready.py record codex
  → sketchybar --trigger ai_ready
  → task-ready.sh shows badge

OpenCode session execution succeeded
  → ~/.config/opencode/plugins/2026-11-01-sketchybar-ready.js
  → task-ready.py record opencode
  → sketchybar --trigger ai_ready
  → task-ready.sh shows badge
```

## Components

| Component | Installed path | In repo |
|---|---|---|
| SketchyBar config | `~/.config/sketchybar` | `config/sketchybar` (sources only) |
| Display transfer | `~/.config/sketchybar/helper/2026-11-01-display-transfer-fast` | source + `--plan`/`--self-test` logic |
| Tile picker | `~/.config/sketchybar/helper/2026-11-01-tile-picker` | source + wrapper + 251 configs |
| Codex notify wrapper | `~/.config/sketchybar/plugins/2026-11-01-codex-ready.py` | yes |
| Codex notify setting | `~/.codex/config.toml` `notify` | snippet only |
| OpenCode plugin | `~/.config/opencode/plugins/2026-11-01-sketchybar-ready.js` | yes |
| Task inbox | `~/.cache/sketchybar/2026-11-01-task-ready.sqlite3` | schema documented, DB not copied |
| BTT triggers | BTT data store | export JSON + patch plans |
| Karabiner | `~/.config/karabiner/karabiner.json` | yes |
| Key remap LaunchAgent | `~/Library/LaunchAgents/com.local.KeyRemapping.plist` | yes |
| SketchyBar LaunchAgent | `~/Library/LaunchAgents/homebrew.mxcl.sketchybar.plist` | yes |
| fish config | `~/.config/fish/config.fish` | yes |

## What is intentionally not copied

- BTT SQLite data store and licence (proprietary database, licence/account data).
- `~/.config/opencode/service.json` (contains a password) and `opencode.json` (API key reference).
- App token stores and caches.
- credential stores, API keys and app databases.
- Compiled helpers and `.app` bundles; rebuild from source.
- SketchyBar backup folders and `.DS_Store`.
- yabai/skhd configs: both are installed on disk but no longer used. They are not part of the
  active setup and are excluded.

## Status of the main features

| Feature | Status |
|---|---|
| Bar renders, items, popups | Working |
| Focus timer / menu | Working |
| Codex usage popup | Working |
| Codex ready badge | Working |
| OpenCode ready badge (v2 plugin) | Working |
| Badge auto-clear on app focus | Working |
| 4-finger display transfer | Working, socket path |
| Half + companion picker | Working |
| Half width cycling | Working |
| BTT persistence across restart | Working after replacing existing actions |
| Karabiner Caps-Lock nav | Working |
| hidutil remap LaunchAgent | Working |

## Reading order

1. [SketchyBar](01-sketchybar.md)
2. [BTT](02-btt.md)
3. [Window management](03-window-management.md)
4. [Task-ready badges](04-task-ready.md)
5. [Keyboard](05-keyboard.md)
6. [Restore](08-install-restore.md)
7. [Troubleshooting](09-troubleshooting.md)
