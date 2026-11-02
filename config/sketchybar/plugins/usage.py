#!/usr/bin/env python3
# agent cell usage — reads local files only (no network, no tokens):
#   Claude: cachedUsageUtilization in ~/.claude.json (where Claude Code stores the /usage values) — only this block is read
#   Codex : the last rate_limits in the final 200KB of the newest rollout-*.jsonl under ~/.codex/sessions
# Output is only the fields agent.sh uses. A value whose reset time has passed is unused in the new window → 0% (no reset time)
#   (Codex writes a new record on every use, so no record after the reset means 0 is right.)
import json, os, glob, time, datetime as D
H = os.path.expanduser("~"); now = time.time()
def live(iso):
    try: return D.datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp() > now
    except Exception: return False
out = {}
try:
    fs = [f for d in ("sessions", "archived_sessions") for f in glob.glob(f"{H}/.codex/{d}/**/rollout-*.jsonl", recursive=True)]
    best = None
    # Candidates = 10 newest by name date + 10 newest by mtime (10-06). By name alone, new values appended to a resumed session with an old name are missed;
    #   by mtime alone, an old file gets picked when Codex touches all the times at once. The value is the newest by each line's timestamp
    cand = list(dict.fromkeys(sorted(fs, key=os.path.basename, reverse=True)[:10] + sorted(fs, key=os.path.getmtime, reverse=True)[:10]))
    for f in cand:
        with open(f, "rb") as fh:
            fh.seek(max(0, os.path.getsize(f) - 200000)); tail = fh.read().decode("utf8", "ignore")
        for line in tail.split("\n"):
            if '"rate_limits"' not in line: continue
            try: row = json.loads(line)
            except Exception: continue
            lim = (row.get("payload") or {}).get("rate_limits") or {}
            if not isinstance((lim.get("primary") or {}).get("used_percent"), (int, float)): continue
            at = row.get("timestamp", "")
            if not best or at > best[0]: best = (at, lim)
    if best:
        p, s = best[1].get("primary") or {}, best[1].get("secondary") or {}
        iso = lambda t: D.datetime.fromtimestamp(t, D.timezone.utc).isoformat() if t else ""
        c = {}
        ok = live(iso(p.get("resets_at"))); c.update(five=round(p["used_percent"]) if ok else None, fiveResetsAt=iso(p.get("resets_at")) if ok else "")
        if isinstance(s.get("used_percent"), (int, float)):
            ok = live(iso(s.get("resets_at"))); c.update(week=round(s["used_percent"]) if ok else None, weekResetsAt=iso(s.get("resets_at")) if ok else "")
        out["codex"] = c
except Exception: pass
print(json.dumps(out))
