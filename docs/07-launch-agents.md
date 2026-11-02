# Launch agents

## Included

| Label | File | Purpose | Status |
|---|---|---|---|
| `homebrew.mxcl.sketchybar` | [`config/launchagents/homebrew.mxcl.sketchybar.plist`](../config/launchagents/homebrew.mxcl.sketchybar.plist) | Start/keep SketchyBar running | Loaded, `KeepAlive` |
| `com.local.KeyRemapping` | [`config/launchagents/com.local.KeyRemapping.plist`](../config/launchagents/com.local.KeyRemapping.plist) | Apply the hidutil HID remap at login | Loaded, `RunAtLoad` |

Both are user LaunchAgents in `~/Library/LaunchAgents/`.

## Not included

These are installed but are app updaters/services, not part of the custom setup:

- `com.google.GoogleUpdater.wake`
- `com.stremio.service`

Karabiner-Elements also registers its own services
(`org.pqrs.service.agent.Karabiner-*`); those come with the app.

## Inspect

```bash
launchctl list | grep -E 'sketchybar|KeyRemapping|karabiner'
launchctl print gui/$(id -u)/homebrew.mxcl.sketchybar | head -40
launchctl print gui/$(id -u)/com.local.KeyRemapping | head -40
```

## Reload

SketchyBar:

```bash
brew services restart sketchybar
# or
launchctl kickstart -k gui/$(id -u)/homebrew.mxcl.sketchybar
```

Key remapping:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.local.KeyRemapping.plist 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.KeyRemapping.plist
```

## Restore

Copy the two plists to `~/Library/LaunchAgents/`, then bootstrap them:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/homebrew.mxcl.sketchybar.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.KeyRemapping.plist
```

If SketchyBar is installed through Homebrew, `brew services start sketchybar` recreates its plist
automatically; the copy here is a record, not the only way to start it.
