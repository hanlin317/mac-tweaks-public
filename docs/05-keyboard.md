# Keyboard

Two layers are active: **Karabiner-Elements** for complex key behaviour, and a **hidutil**
LaunchAgent for low-level HID remapping.

## Karabiner-Elements

Config: [`config/keyboard/karabiner.json`](../config/keyboard/karabiner.json)
(`~/.config/karabiner/karabiner.json`).

One profile, `Default profile`, selected. Two complex-modification rules are present:

| Rule | Enabled | Behaviour |
|---|---|---|
| Caps Lock: Hold for WASD-Arrows, Tap for Escape | yes | Holding Caps Lock activates a navigation layer: `W/A/S/D` → up/left/down/right arrows; tapping Caps Lock sends Escape |
| Home row mods - ctrl, opt, shift, command | **no** | Present but disabled: `A+S+D+F` held together would send a combined left modifier |

The disabled rule is kept for reference. Enabling it would make the home row chord a modifier, which
conflicts with normal typing unless you use a dedicated layer.

Karabiner also has its own virtual keyboard and event taps; the Karabiner core service is running.

## hidutil LaunchAgent

Files:

- [`config/keyboard/com.local.KeyRemapping.plist`](../config/keyboard/com.local.KeyRemapping.plist)
- [`config/launchagents/com.local.KeyRemapping.plist`](../config/launchagents/com.local.KeyRemapping.plist)

The agent runs at login and applies:

```json
{"UserKeyMapping":[
  {"HIDKeyboardModifierMappingSrc": 0xC000000CF, "HIDKeyboardModifierMappingDst": 0xFF00000009},
  {"HIDKeyboardModifierMappingSrc": 0x10000009B, "HIDKeyboardModifierMappingDst": 0xFF00000008}
]}
```

This is a low-level remap applied to every keyboard. The source/destination usages are preserved
exactly as installed; the full mapping is in the plist above.

Check the live value:

```bash
hidutil property --get UserKeyMapping
```

Reload the agent:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.local.KeyRemapping.plist 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.KeyRemapping.plist
```

If a key behaves unexpectedly, check both Karabiner and `hidutil`; they act at different layers and
can both affect the same key.

## Shell

- Login shell: `/bin/zsh`.
- fish config is in [`config/shell/config.fish`](../config/shell/config.fish): conda initialization
  and `~/.local/bin` on `PATH`.
- The zsh configuration is not copied here; only the fish file was present under `~/.config`.

## Restore

1. Install Karabiner-Elements.
2. Copy `karabiner.json` to `~/.config/karabiner/karabiner.json`.
3. Copy the KeyRemapping plist to `~/Library/LaunchAgents/` and bootstrap it (or log out/in).
4. Open Karabiner-Elements and confirm the profile is selected.
5. Test: tap Caps Lock → Escape; hold Caps Lock + WASD → arrows.
