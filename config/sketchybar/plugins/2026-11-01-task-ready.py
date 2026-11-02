#!/usr/bin/env python3
"""Local, metadata-only completion inbox. No notification, sound or network."""
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import time


def connect(root=None):
    root = Path(root) if root else Path.home()/'.cache/sketchybar'
    root.mkdir(parents=True, exist_ok=True)
    path = root/'2026-11-01-task-ready.sqlite3'
    old = os.umask(0o077)
    try:
        db = sqlite3.connect(path, timeout=.25)
        db.execute('CREATE TABLE IF NOT EXISTS ready (source TEXT, token TEXT, at REAL, ack INTEGER DEFAULT 0, PRIMARY KEY(source,token))')
        os.chmod(path, 0o600)
    finally:
        os.umask(old)
    return db


def mark(source, session, event, root=None, trigger=True):
    if source not in ('codex', 'opencode') or not session or not event:
        return False
    token = hashlib.sha256((str(session)[:512]+'\0'+str(event)[:512]).encode()).hexdigest()
    with connect(root) as db:
        changed = db.execute('INSERT OR IGNORE INTO ready(source,token,at) VALUES(?,?,?)', (source, token, time.time())).rowcount > 0
        db.execute('DELETE FROM ready WHERE ack=1 AND at < ?', (time.time()-7*86400,))
    if changed and trigger:
        try:
            subprocess.run(['/opt/homebrew/bin/sketchybar', '--trigger', 'ai_ready'], timeout=1, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except (OSError, subprocess.TimeoutExpired):
            pass
    return changed


def acknowledge(source, root=None):
    if source not in ('codex', 'opencode'):
        raise ValueError('Invalid source')
    with connect(root) as db:
        db.execute('UPDATE ready SET ack=1 WHERE source=?', (source,))


def status(root=None):
    with connect(root) as db:
        return {s: db.execute('SELECT COUNT(*) FROM ready WHERE source=? AND ack=0', (s,)).fetchone()[0] for s in ('codex','opencode')}


if __name__ == '__main__':
    if sys.argv[1] == 'record':
        mark(*sys.argv[2:5])
    elif sys.argv[1] == 'ack':
        acknowledge(sys.argv[2])
    elif sys.argv[1] == 'status':
        print(json.dumps(status()))
    else:
        raise ValueError('Unknown command')
