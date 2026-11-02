# Task-ready badges (Codex + OpenCode)

Bar-only completion indicators. They do not play sounds or create macOS notifications.

## Flow

```
Codex turn end
  ~/.codex/config.toml notify
    → SkyComputerUseClient turn-ended --previous-notify [python3 codex-ready.py]
    → codex-ready.py: record codex (and do not forward when the SkyComputerUse ancestor is detected)
    → task-ready.py record codex <session> <event>
    → sketchybar --trigger ai_ready
    → task-ready.sh renders ready.codex

OpenCode execution succeeded
  ~/.config/opencode/plugins/2026-11-01-sketchybar-ready.js
    → task-ready.py record opencode <session> <event.id>
    → sketchybar --trigger ai_ready
    → task-ready.sh renders ready.opencode
```

## Codex notify hook

Current `~/.codex/config.toml` notify value:

```toml
notify = ["/Users/yourname/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient", "turn-ended", "--previous-notify", "[\"\\/opt\\/homebrew\\/bin\\/python3\",\"\\/Users\\/yourname\\/.config\\/sketchybar\\/plugins\\/2026-11-01-codex-ready.py\"]"]
```

The Codex app writes this line; it may rewrite it on launch. The wrapper:

- detects a `SkyComputerUse` ancestor with `ps`;
- in that mode records the event and **does not forward** (prevents recursion);
- when invoked directly, forwards the original command and payload unchanged;
- logs only the event type and whether thread/turn IDs existed, never content.

Log: `~/.cache/sketchybar/2026-11-01-codex-notify.log`.

If the notification stops, check the log and confirm the `notify` line still points at
`SkyComputerUseClient turn-ended --previous-notify [python3 2026-11-01-codex-ready.py]`.

## OpenCode plugin

OpenCode 2.2.5 uses the v2 plugin API:

```js
export default Plugin.define({ id, setup(ctx) { ... } })
```

Events are delivered as `{ id, created, type, durable, location, data }`; the payload is `data`,
not `properties`. The live stream does **not** emit `session.status` or `session.idle` in the
observed version. The plugin records on:

- `session.execution.succeeded`
- `session.execution.failed`
- `session.execution.interrupted`

The dedupe token is the event `id`, so multiple plugin instances collapse to one inbox row.

Diagnostic logging is disabled: `~/.cache/sketchybar/2026-11-01-opencode-plugin.log` is deliberately
a **directory**, so stale instances cannot write content there. Remove the directory only if you
want to re-enable execution-only diagnostics.

Editing a plugin hot-reloads it; each hot reload can add an instance. A clean OpenCode server restart
is the reliable way to end up with one instance.

## Inbox

`~/.cache/sketchybar/2026-11-01-task-ready.sqlite3`, mode `0600`:

```sql
CREATE TABLE ready (
  source TEXT,
  token  TEXT,
  at     REAL,
  ack    INTEGER DEFAULT 0,
  PRIMARY KEY(source, token)
);
```

`source` is `codex` or `opencode`; `token` is a hashed event/session token. No prompt text, code or
window content is stored.

Commands:

```bash
python3 ~/.config/sketchybar/plugins/2026-11-01-task-ready.py status
python3 ~/.config/sketchybar/plugins/2026-11-01-task-ready.py record codex <session> <event>
python3 ~/.config/sketchybar/plugins/2026-11-01-task-ready.py ack codex
```

## Badges

- `ready.codex` / `ready.opencode` are hidden by default.
- Label is `Codex ready` or `OpenCode ready`, with `(N)` when more than one unacknowledged row.
- Clicking a badge acks that source.
- Switching to the app that finished clears its badge:
  - `com.openai.codex` → Codex
  - `ai.opencode.desktop` → OpenCode
- If you are already in that app when the task completes, the badge is suppressed on the next run.
- Hidden badges clear their label, so a stale count cannot flash back.

The watcher (`ready.watch`) runs with `updates=on update_freq=300` and subscribes to `ai_ready`,
`system_woke` and `front_app_switched`. `updates=off` was tested and suppresses event scripts
entirely, so it must not be used.

## Privacy

- Codex wrapper logs event type / ID presence only.
- OpenCode plugin logs execution-only diagnostics, and the log path is currently blocked.
- The inbox stores hashed tokens, timestamps and source names.
- No conversation content, prompts, code, window titles or images are recorded.

## Limits

- Codex may rewrite `notify` on launch; the chain relies on `SkyComputerUseClient --previous-notify`.
- OpenCode event names are version-specific; re-check after an OpenCode update.
- Duplicate rows can appear after plugin hot reloads until a clean server restart.
