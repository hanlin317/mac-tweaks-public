# Test tools

These are self-contained tools used while developing the tiling helpers. They only touch their own
test app when invoked with `--pid` / `--only-pid`.

Build:

```bash
cd scripts/tests
for f in *.swift; do swiftc -target arm64-apple-macos14.0 -O "$f" -o "${f%.swift}"; done
```

- `2026-11-01-picker-testapp.swift`: three standard windows, first focused.
- `2026-11-01-ax-fix-rect.swift`: move a specific AX window by current rect:
  `ax-fix-rect pid cx cy cw ch tx ty tw th`
- `2026-11-01-ax-front.swift`: set an app frontmost via AX (test only).

Do not run these against real apps. The picker itself supports `--pid` and `--only-pid` so tests
cannot select a window outside the test app.
