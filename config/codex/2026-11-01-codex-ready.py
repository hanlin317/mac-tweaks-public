#!/opt/homebrew/bin/python3
"""Chain the existing Codex notify command unchanged, adding a bar-only inbox event.

The Codex app may install its computer-use client as the primary notify target and
pass this script as "--previous-notify". In that case the client has already run,
so this script must NOT call it again (that would recurse). We detect the parent
process and only forward when we were invoked directly by the Codex config.
"""
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import time

ORIGINAL = [str(Path.home() / '.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient'), 'turn-ended']
LOG = Path.home() / '.cache/sketchybar/2026-11-01-codex-notify.log'


def note(message):
    """Diagnostics only: no payload contents, thread IDs or user text."""
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open('a') as f:
            f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S')} {message}\n")
    except Exception:
        pass


def invoked_by_computer_use(depth=4):
    """True when a SkyComputerUse process is an ancestor (previous-notify mode)."""
    pid = os.getpid()
    for _ in range(depth):
        try:
            ppid_text = subprocess.check_output(['/bin/ps', '-o', 'ppid=', '-p', str(pid)], text=True).strip()
            if not ppid_text:
                return False
            ppid = int(ppid_text.split()[0])
            if ppid <= 1:
                return False
            command = subprocess.check_output(['/bin/ps', '-o', 'command=', '-p', str(ppid)], text=True)
        except Exception:
            return False
        if 'SkyComputerUse' in command:
            return True
        pid = ppid
    return False


def dispatch(arguments, mark, forward):
    try:
        data = json.loads(arguments[-1])
        if data.get('type') == 'agent-turn-complete':
            note(f"agent-turn-complete thread={'yes' if data.get('thread-id') else 'no'} turn={'yes' if data.get('turn-id') else 'no'}")
            mark('codex', data.get('thread-id'), data.get('turn-id'))
        else:
            note(f"ignored type={data.get('type')!r}")
    except Exception as error:
        note(f"payload unreadable ({type(error).__name__}); argv={len(arguments)}")
    return forward(ORIGINAL + arguments)


if __name__ == '__main__':
    def mark(*args):
        module = runpy.run_path(str(Path.home()/'.config/sketchybar/plugins/2026-11-01-task-ready.py'))
        module['mark'](*args)

    if invoked_by_computer_use():
        note('previous-notify mode: mark only, no forward')
        dispatch(sys.argv[1:], mark, lambda argv: 0)
        sys.exit(0)
    note('direct mode: mark and forward to computer-use client')
    dispatch(sys.argv[1:], mark, lambda argv: os.execv(argv[0], argv))
