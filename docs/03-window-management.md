# Window management

This Mac uses BTT for window management. yabai and skhd are installed on disk but **no longer
running and not part of the active setup**; their old configs are not included.

## Geometry

The tiling work area is derived from the display bounds:

```
work = (screen.x + 5, screen.y + 43, screen.width - 10, screen.height - 48)
```

So on the MacBook (`0,0,1800×1169`) the work area is `5,43,1790×1121`, and on the external display
(`-2560,-160,2560×1440`) it is `-2555,-117,2550×1392`.

Halves:

- left: `x = work.minX`, `w = (work.width - 5) / 2`
- right: `x = work.maxX - w`, same `w`
- top: `y = work.minY`, `h = (work.height - 5) / 2`
- bottom: `y = work.maxY - h`, same `h`

This gives a 5 pt gap between paired halves. The numbers match BTT's original half configurations.

### Width fractions

Left/right width cycling uses fractions of the usable width (`work.width - 5`):

```
w = (work.width - 5) * fraction
left  x = work.minX
right x = work.maxX - w
```

Fractions: `1/2`, `2/3`, `1/3`.

Measured on the MacBook:

| Side | 1/2 | 2/3 | 1/3 |
|---|---|---|---|
| Left | `5,43,892×1121` | `5,43,1190×1121` | `5,43,595×1121` |
| Right | `902,43,892×1121` | `605,43,1190×1121` | `1200,43,595×1121` |

A window is considered docked when its side anchor, width and height are within **8 pt**. A window
whose height was changed is not docked and is halved again rather than cycled.

## Half + companion picker

After a normal half, the picker lists other normal windows on the same display. Choosing one fills
the opposite half.

- Only windows intersecting the display of the just-halved window.
- Excludes the active window, the picker itself, minimised windows, native full-screen windows, and
  windows already exactly filling either half.
- Window titles come from `AXTitle`; no window content is read.
- Keys: `↑`/`↓` select, `Enter` tile, `1`–`9` pick, single click picks, `Esc` cancels.
- Auto-cancels after 8 seconds.
- Panel is 320 pt wide, six rows visible with scrolling, dark HUD style.
- Appears centred in the free half.
- No panel when there are no candidates.

Chosen window move:

1. direct AX position/size (leaves the original focus alone);
2. if the app clamps, activate the app, raise the window, set the focused window, dispatch BTT 446;
3. verify from `CGWindowList` and correct with AX if needed.

Single instance: `flock` on `~/.cache/sketchybar/2026-11-01-tile-picker.lock`. A newer gesture
terminates the older picker and takes over, so panels never stack.

## Width cycling

Only the **top-left** and **top-right** corner clicks cycle. Side taps (top/bottom halves) still do
the normal half + picker.

Cycle order:

```
1/2 → 2/3 → 1/3 → 1/2
```

- Left-docked keeps the left edge; right-docked keeps the right edge.
- No panel is shown for a cycle.
- If the window is not docked to the requested side, the normal half + picker runs instead.
- The cycle is applied by the wrapper's first pass; the original 251 is not run for a cycle.

Why no panel: cycling is a width adjustment, not a new tiling operation. The panel would cover the
area you are adjusting.

## Display transfer

The 4-finger swipes call `2026-11-01-display-transfer-fast left|right`.

- Uses public CoreGraphics/AppKit window metadata; no titles, images, private APIs or new
  permissions.
- Sends **one** BTT type-446 action with global `x,y,w,h`.
- A single 251 with monitor movement clamped large targets to the destination visible area
  (1286 instead of 1392); 251→446 produced a visible two-step. Do not reintroduce either.
- Verifies the final rect from `CGWindowList`; corrects with a public AX position-then-size write
  only if needed.
- Skips native full-screen spaces.
- Fast path uses the BTT socket (`bttcli`, ~45 ms dispatch); falls back to AppleScript (~250–400 ms)
  if the socket is unavailable.
- BTT's own shell spawn (~150 ms) is outside the helper timing; total is roughly 350–400 ms.
- A large-target move can produce one intermediate frame for ~12–15 ms before the correction; this
  is a BTT behaviour and is imperceptible in normal use.

Last-run diagnostics: `~/.cache/sketchybar/2026-11-01-display-transfer-last.json`.

## Edge cases

- **Native full-screen**: the picker exits without changing the window. The display-transfer helper
  also skips it.
- **Same display only**: the picker does not list windows on other Spaces or displays.
- **Minimum sizes**: an app that refuses both AX resizing and BTT 446 may not reach the exact rect.
  The result is verified and logged.
- **Multiple windows of the same app**: matched by pid + rect from `CGWindowList`; titles are
  secondary.
- **Different displays**: the display is chosen by the largest intersection with the active window's
  rect; ties use the nearest centre.

## Test tools

The repo keeps the self-contained test pieces under `scripts/tests/`:

- `2026-11-01-picker-testapp.swift`: three standard windows, one focused.
- `2026-11-01-ax-fix-rect.swift`: move a specific AX window by matching its current rect.
- `2026-11-01-ax-front.swift`: make a specific app frontmost via AX (test only).

Build them with `swiftc -target arm64-apple-macos14.0`. Use `--pid` and `--only-pid` when testing the
picker so it cannot touch real windows.

## Diagnostics

```bash
# last picker/cycle result
cat ~/.cache/sketchybar/2026-11-01-tile-picker-last.json

# every effective picker/cycle launch
tail ~/.cache/sketchybar/2026-11-01-tile-picker-starts.log

# last display transfer
cat ~/.cache/sketchybar/2026-11-01-display-transfer-last.json

# geometry self-test
~/.config/sketchybar/helper/2026-11-01-tile-picker --self-test
```

Expected self-test output: 8 geometry cases and 12 fraction cases, `result: pass`.
