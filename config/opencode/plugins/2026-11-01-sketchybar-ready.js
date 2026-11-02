import { Plugin } from "@opencode/plugin"
import { execFile } from "node:child_process"
import { randomUUID } from "node:crypto"
import { appendFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

// OpenCode v2 plugin. v2 events are { id, created, type, durable, location, data };
// the payload is in `data` (v1 used `properties`).
const RECORD = join(homedir(), ".config", "sketchybar", "plugins", "2026-11-01-task-ready.py")
const LOG = join(homedir(), ".cache", "sketchybar", "2026-11-01-opencode-plugin.log")

function note(message) {
  try {
    appendFileSync(LOG, `${new Date().toISOString()} ${message}\n`)
  } catch {}
}

export default Plugin.define({
  id: "sketchybar.ready",
  setup(ctx) {
    const controller = new AbortController()
    const busy = new Map()
    note(`setup loaded; app=${ctx.app?.version ?? "?"}`)

    const record = (session, token) =>
      new Promise((resolve) => {
        execFile(
          "/opt/homebrew/bin/python3",
          [RECORD, "record", "opencode", session, token],
          { timeout: 1500 },
          (error) => {
            note(`record session=${session.slice(0, 8)} error=${error ? error.message : "none"}`)
            resolve()
          },
        )
      })

    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          const data = event.data || {}
          if (
            event.type === "session.execution.started" ||
            event.type === "session.execution.succeeded" ||
            event.type === "session.execution.failed" ||
            event.type === "session.execution.interrupted"
          ) {
            note(`${event.type} session=${data.sessionID ? "yes" : "no"}`)
          }
          const session =
            data.sessionID ||
            data.sessionId ||
            data.session?.id ||
            data.info?.sessionID ||
            data.info?.id
          if (typeof session !== "string" || !session || session.length > 512) continue
          const status = data.status?.type ?? data.status

          if (event.type === "session.error" || event.type === "session.deleted") {
            busy.delete(session)
          } else if (event.type === "session.execution.started") {
            if (!busy.has(session)) busy.set(session, event.id || data.executionID || randomUUID())
          } else if (event.type === "session.execution.succeeded") {
            const token = busy.get(session) || event.id || data.executionID || randomUUID()
            busy.delete(session)
            await record(session, token)
          } else if (event.type === "session.status" && status === "busy") {
            if (!busy.has(session)) busy.set(session, event.id || randomUUID())
          } else if (
            event.type === "session.idle" ||
            (event.type === "session.status" && status === "idle")
          ) {
            const token = busy.get(session)
            if (!token) continue
            busy.delete(session)
            await record(session, token)
          }
        }
      } catch (error) {
        note(`subscription ended: ${error?.message ?? error}`)
      }
    })()

    return () => controller.abort()
  },
})
