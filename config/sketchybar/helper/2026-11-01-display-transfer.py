#!/usr/bin/env python3
"""Plan a BTT move using fresh window coordinates and SketchyBar display geometry."""
import json
import math
import subprocess
import sys

TOP, EDGE, GAP = 43.0, 5.0, 5.0


def area(a, b):
    return max(0, min(a[0]+a[2], b[0]+b[2])-max(a[0], b[0])) * max(0, min(a[1]+a[3], b[1]+b[3])-max(a[1], b[1]))


def usable(d):
    f = d['frame']
    return [f['x']+EDGE, f['y']+TOP, f['w']-2*EDGE, f['h']-TOP-EDGE]


def tiles(d):
    x, y, w, h = usable(d)
    out = [('full', [x, y, w, h])]
    for n in (2, 3):
        width = (w-(n-1)*GAP)/n
        for i in range(n):
            out.append((f'{i+1}/{n}', [x+i*(width+GAP), y, width, h]))
    return out


def plan(rect, displays, direction):
    if len(rect) != 4 or not all(math.isfinite(v) for v in rect) or min(rect[2:]) <= 0:
        raise ValueError('Invalid window geometry')
    if len(displays) < 2:
        return None
    displays = sorted(displays, key=lambda d: (d['frame']['x'], d['frame']['y']))
    source = max(displays, key=lambda d: area(rect, [d['frame'][k] for k in ('x','y','w','h')]))
    if area(rect, [source['frame'][k] for k in ('x','y','w','h')]) <= 0:
        raise ValueError('Window does not overlap an attached display')
    target = displays[(displays.index(source) + (-1 if direction == 'left' else 1)) % len(displays)]
    sx, sy, sw, sh = usable(source)
    tx, ty, tw, th = usable(target)
    name = 'proportional'
    # Recognize half/third/full-height layouts, including Raycast's smaller edge gaps.
    if rect[3] >= sh * .85:
        for candidate, tile in tiles(source):
            if abs(rect[0]-tile[0]) <= 16 and abs(rect[2]-tile[2]) <= 16:
                name = candidate
                dest = dict(tiles(target))[candidate]
                break
        else:
            dest = None
    else:
        dest = None
    if dest is None:
        w = min(tw, max(1, rect[2]/sw*tw))
        h = min(th, max(1, rect[3]/sh*th))
        x = min(tx+tw-w, max(tx, tx+(rect[0]-sx)/sw*tw))
        y = min(ty+th-h, max(ty, ty+(rect[1]-sy)/sh*th))
        dest = [x, y, w, h]
    dest = [round(v) for v in dest]
    return {'layout': name, 'rect': dest,
            'action': {'BTTPredefinedActionType': 446, 'BTTGenericActionConfig': ','.join(map(str, dest))}}


if __name__ == '__main__':
    direction = sys.argv[1]
    if direction not in ('left', 'right'):
        raise ValueError('Invalid direction')
    displays = json.loads(subprocess.check_output(['/opt/homebrew/bin/sketchybar', '--query', 'displays'], timeout=2))
    result = plan(list(map(float, sys.argv[2:6])), displays, direction)
    print(json.dumps(result['action'] if result else {}))
