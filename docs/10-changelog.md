# Changelog and known limits

## 2026-11-01

- Bar repairs and focus item alignment: `◷` icon `y_offset=3`, label offset `0` to match the
  active-app text. The glyph is not in JetBrains Mono, so exact sub-point centring is not possible.
- Codex usage popup: 5-hour/Weekly headings, 96 pt key column, 300 pt width, two footer rows,
  independent amber/red thresholds.
- Display transfer: replaced the Python planner path with a Swift helper that dispatches one BTT 446
  and verifies the rect. Added the BTT socket fast path and AppleScript fallback.
- Codex completion hook: wrapper around `SkyComputerUseClient turn-ended --previous-notify`,
  recursion guard, bar-only badge.
- OpenCode completion hook: ported from v1 to the v2 plugin API; records on
  `session.execution.succeeded`; token is the event id.
- Badge auto-clear: switching to the finished app acks its source; hidden badges clear their label.
- Watcher: `updates=on update_freq=300` plus `ai_ready` / `system_woke` / `front_app_switched`.
  `updates=off` suppresses event scripts and was rejected.
- Timer trims: clock 10 s, spaces 30 s, front_app 30 s, agent 30 s, focus 1 s running / 30 s idle.
- Half companion picker: panel, keyboard/click selection, AX move with BTT 446 fallback, single
  instance lock.
- BTT half gestures replaced with a persistent action form; display swipes remain type 246.

## 2026-11-02

- BTT auto-updated from 6.455 to 6.990. The appended type-137 actions did not survive the restart.
- Reproduced the persistence behaviour twice: appended actions are dropped; changes to existing
  actions persist.
- Reworked the half gestures: each existing action is now type 137 calling
  `2026-11-01-tile-picker-run <dir>`. The wrapper dispatches the saved original 251 half, then the
  picker with `--already`.
- Added left/right width cycling: 1/2 → 2/3 → 1/3 → 1/2, anchored to the side, no panel.
- Added a native full-screen guard to the picker.
- Verified the four actions survive graceful BTT restarts and execute after a restart.
- Found the `com.apple.macl` install hazard: a replaced binary copied with `cp -p` can be SIGKILLed
  (exit 137); a clean copy works.
- Documentation snapshot and public sanitized repo created.

## Test evidence (condensed)

- Geometry self-test: 8 geometry cases + 12 fraction round-trips, pass.
- Half: active `[5,43,893,1121]`, companion `[902,43,892,1121]`; 183 ms headless, 223 ms via BTT.
- Top half: active `[5,43,1790,558]`, companion `[5,606,1790,558]`; 204 ms.
- Cycle left: `1/2 [5,43,892] → 2/3 [5,43,1190] → 1/3 [5,43,595] → 1/2`.
- Cycle right: `1/2 [902,43,892] → 2/3 [605,43,1190] → 1/3 [1200,43,595] → 1/2`.
- Wrapper cycle: 2/3 → 1/3 in 168 ms via `btt-socket`, no panel.
- Real trigger after BTT restart: 1/2 → 2/3 via `btt-socket`, no panel.
- BTT type 137 returns in ~230 ms, asynchronous, Accessibility trusted.

## Known limits

- **BTT updates**: re-check the four half actions after every BTT update. The current form survives
  6.990 restarts, but a future version may change the persistence rules.
- **Click selection**: implemented as an NSTableView single-click action; keyboard selection was
  verified end to end, click was not manually confirmed.
- **Same display only**: the picker does not list windows on other Spaces or displays.
- **Fixed 8 s timeout**: no preference yet.
- **Panel takes focus**: SketchyBar's active-app item briefly shows `2026-11-01-tile-picker`.
- **Minimum sizes**: apps that refuse AX resizing and BTT 446 may not reach the exact half.
- **Cycle requires full height and an 8 pt side anchor**: a vertically resized half-window is halved
  again.
- **Display transfer**: roughly 350–400 ms including BTT's shell spawn; one intermediate frame of
  ~12–15 ms can occur on large targets.
- **Codex notify**: the app can rewrite `notify` on launch; the chain depends on
  `SkyComputerUseClient --previous-notify`.
- **OpenCode**: event names are version-specific; re-check after an OpenCode update. Hot reloads can
  create duplicate plugin instances until a clean server restart.
- **Wifi scan**: requires Location permission for `WifiScan.app`.
- **Retired**: yabai and skhd configs are not part of the active setup and are excluded.
- **Not implemented**: a health indicator for silently failing scripts, and git version control of
  the live config (this repo is now that version history).
