# Install / restore

This is a source snapshot. It does not include compiled helpers, app databases, credentials or
caches. Restore order matters because a few steps depend on permissions and on BTT being running.

## 1. Prerequisites

- macOS 14+ on arm64 (helpers are built with `-target arm64-apple-macos14.0`)
- Xcode Command Line Tools: `xcode-select --install`
- Homebrew
- [SketchyBar](https://github.com/FelixKratz/SketchyBar): `brew install sketchybar`
- [BetterTouchTool](https://folivora.ai) 6.990 or newer
- [Karabiner-Elements](https://karabiner-elements.pqrs.org)
- Fonts: JetBrains Mono and JetBrainsMono Nerd Font (used by the bar and settings glyph)
- Optional: `media-control` (`brew install media-control`) for the media island
- Optional: Pilo, Rectangle (the config has `PILO_ISLAND=0` and `AUTOMAX=0` by default)
- Python 3 at `/opt/homebrew/bin/python3` (several plugins use it explicitly)

## 2. Copy the configs

From the repo root:

```bash
cp -R config/sketchybar ~/.config/sketchybar
mkdir -p ~/.config/opencode/plugins
cp config/opencode/plugins/2026-11-01-sketchybar-ready.js ~/.config/opencode/plugins/
cp config/keyboard/karabiner.json ~/.config/karabiner/karabiner.json
cp config/shell/config.fish ~/.config/fish/config.fish
cp config/launchagents/*.plist ~/Library/LaunchAgents/
```

Do **not** copy the whole `~/.config/opencode` directory from another machine: `service.json` and
`opencode.json` contain credentials and are intentionally absent here.

For Codex, add the `notify` line from
[`config/codex/notify-snippet.toml`](../config/codex/notify-snippet.toml) to
`~/.codex/config.toml`, and place the wrapper at
`~/.config/sketchybar/plugins/2026-11-01-codex-ready.py`.

## 3. Build the helpers

The repo keeps Swift sources only. From the repo root:

```bash
scripts/build-helpers.sh
```

This compiles every `helper/*.swift` into the repo's `config/sketchybar/helper/` folder and builds
`WifiScan.app` (Location permission) and `2026-11-01-CalendarAccess.app` (Calendar permission). Then copy the built binaries into the live config:

```bash
cp config/sketchybar/helper/2026-11-01-display-transfer-fast ~/.config/sketchybar/helper/
cp config/sketchybar/helper/2026-11-01-tile-picker ~/.config/sketchybar/helper/
cp config/sketchybar/helper/2026-11-01-menu-bar-coordinator ~/.config/sketchybar/helper/
cp -R config/sketchybar/helper/WifiScan.app config/sketchybar/helper/2026-11-01-CalendarAccess.app ~/.config/sketchybar/helper/
# plus any other helpers the bar uses
```

### Binary install hazard

If you copy a helper with `cp -p`, it can carry a stale `com.apple.macl` xattr from the old binary.
macOS may SIGKILL the new binary (exit 137). Install with:

```bash
cat new-binary > ~/.config/sketchybar/helper/helper-name
chmod 755 ~/.config/sketchybar/helper/helper-name
xattr -c ~/.config/sketchybar/helper/helper-name
codesign --force --sign - ~/.config/sketchybar/helper/helper-name  # optional, ad-hoc
```

This was observed when replacing the tile picker. The clean copy ran; the `cp -p` copy was killed.

## 4. Permissions

Grant the following in **System Settings → Privacy & Security**:

| Permission | Granted to | Used by |
|---|---|---|
| Accessibility | BetterTouchTool | Window moves, gestures |
| Accessibility | (the terminal you launch helpers from, for testing) | AX test tools |
| Screen Recording | Optional; only if a helper falls back to `CGWindowName` | Window titles |
| Location | `WifiScan.app` | Nearby Wi-Fi names |
| Calendar | `CalendarAccess.app` / the calendar helper | Calendar events |

The picker normally uses `AXTitle`, which does not require Screen Recording.

## 5. Start SketchyBar

```bash
brew services start sketchybar
# or
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/homebrew.mxcl.sketchybar.plist
```

Check:

```bash
sketchybar --version
sketchybar --query bar
```

If the bar is blank, check `~/.config/sketchybar/helper/` for missing binaries and the Homebrew log
at `/opt/homebrew/var/log/sketchybar/sketchybar.err.log`.

## 6. BetterTouchTool

The repo includes the current half-gesture map at
[`config/btt/half-gestures.json`](../config/btt/half-gestures.json) and the saved 251 configs.
The example commands use `/Users/yourname`; replace that with your home directory.

Two ways to restore:

1. **BTT UI / preset import**: import the JSON export (or recreate the gestures) and then verify the
   action UUIDs.
2. **AppleScript patch** (what this setup uses): update the existing half actions with type 137 and
   the wrapper command. See [02-btt.md](02-btt.md#re-apply-the-half-actions).

Enable the BTT socket:

`Settings → Scripting BTT → Command Line → Enable BTT Socket Server For Command Line Usage`.

The socket is required for the fast display-transfer path and for the 446 dispatches.

After any BTT update, run:

```bash
scripts/verify.sh
```

BTT 6.990 drops **appended** actions on restart; the setup replaces existing actions instead. Do not
"add" a second action to a half trigger.

## 7. Codex and OpenCode

- Codex: add the `notify` line to `~/.codex/config.toml`; the wrapper must be executable.
- OpenCode: the plugin is loaded from `~/.config/opencode/plugins/`; restart the OpenCode server
  after installing or editing it.
- The inbox database is created automatically at
  `~/.cache/sketchybar/2026-11-01-task-ready.sqlite3` (mode 0600).

## 8. Verify

```bash
scripts/verify.sh
~/.config/sketchybar/helper/2026-11-01-tile-picker --self-test
```

Manual checks:

- Bar renders on all displays.
- Focus timer ticks once per second while running.
- Codex/OpenCode badges appear after a completion and clear when you switch to the app.
- 4-finger display swipe moves the window with the exact rect.
- Corner half + picker; second click cycles 1/2 → 2/3 → 1/3.
- Karabiner: tap Caps Lock = Escape; hold + WASD = arrows.

## 9. macOS system settings

System-level defaults (Dock, Finder, key repeat, hot corners, menu bar extras, etc.) are not
snapshotted here. They are personal, change often, and are better reviewed in System Settings on the
new machine. This repo captures the custom automation and the app-level configs, not every macOS
preference.

## 10. What is not restorable from this repo

- BTT's internal data store, licence and account state.
- App credentials, keychain items and API keys.
- App databases, caches and personal script commands.
- iTerm2/kitty/other app profiles.
