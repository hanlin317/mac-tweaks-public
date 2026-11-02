import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Darwin

struct Layout {
    let name: String
    let rect: CGRect
}
func workArea(_ screen: CGRect) -> CGRect {
    CGRect(x: screen.minX + 5, y: screen.minY + 43, width: screen.width - 10, height: screen.height - 48)
}
func layouts(_ screen: CGRect) -> [Layout] {
    let r = workArea(screen)
    var result = [Layout(name: "full", rect: r)]
    for n in [2, 3] {
        let w = (r.width - CGFloat(n - 1) * 5) / CGFloat(n)
        for i in 0..<n {
            result.append(Layout(name: "\(i + 1)/\(n)", rect: CGRect(x: r.minX + CGFloat(i) * (w + 5), y: r.minY, width: w, height: r.height)))
        }
    }
    return result
}
func area(_ a: CGRect, _ b: CGRect) -> CGFloat {
    let r = a.intersection(b)
    return r.isNull ? 0 : r.width * r.height
}
func plan(_ window: CGRect, _ screens: [CGRect], _ direction: String) -> Layout? {
    guard screens.count > 1, window.width > 0, window.height > 0 else { return nil }
    let ds = screens.sorted { $0.minX == $1.minX ? $0.minY < $1.minY : $0.minX < $1.minX }
    guard let index = ds.indices.max(by: { area(window, ds[$0]) < area(window, ds[$1]) }), area(window, ds[index]) > 0 else { return nil }
    let target = ds[(index + (direction == "left" ? ds.count - 1 : 1)) % ds.count]
    let source = workArea(ds[index]), dest = workArea(target)
    if window.height >= source.height * 0.85,
       let match = layouts(ds[index]).first(where: { abs(window.minX - $0.rect.minX) <= 16 && abs(window.width - $0.rect.width) <= 16 }),
       let tile = layouts(target).first(where: { $0.name == match.name }) { return tile }
    let w = min(dest.width, max(1, window.width / source.width * dest.width))
    let h = min(dest.height, max(1, window.height / source.height * dest.height))
    return Layout(name: "proportional", rect: CGRect(
        x: min(dest.maxX - w, max(dest.minX, dest.minX + (window.minX - source.minX) / source.width * dest.width)),
        y: min(dest.maxY - h, max(dest.minY, dest.minY + (window.minY - source.minY) / source.height * dest.height)), width: w, height: h))
}

// One native action: move + size in a single BTT operation. A single 251 was
// clamped by BTT when the destination was larger; a single 446 reaches the exact rect.
func action(_ r: CGRect) -> [String: Any] {
    let x = Int(r.minX.rounded()), y = Int(r.minY.rounded()), w = Int(r.width.rounded()), h = Int(r.height.rounded())
    return ["BTTPredefinedActionType": 446, "BTTGenericActionConfig": "\(x),\(y),\(w),\(h)"]
}
func payload(_ r: CGRect) -> String {
    let data = try! JSONSerialization.data(withJSONObject: ["BTTActionsToExecute": [action(r)]], options: [.sortedKeys])
    return String(data: data, encoding: .utf8)!
}

struct Snapshot {
    let pid: pid_t
    let id: CGWindowID
    let rect: CGRect
}
func allRows() -> [[String: Any]]? {
    CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
}
func snapshot() -> Snapshot? {
    guard let app = NSWorkspace.shared.frontmostApplication, let rows = allRows() else { return nil }
    for row in rows {
        guard row[kCGWindowOwnerPID as String] as? pid_t == app.processIdentifier,
              row[kCGWindowLayer as String] as? Int == 0,
              let dict = row[kCGWindowBounds as String] as? [String: Any],
              let rect = CGRect(dictionaryRepresentation: dict as CFDictionary), rect.width > 100, rect.height > 80,
              let id = row[kCGWindowNumber as String] as? CGWindowID else { continue }
        return Snapshot(pid: app.processIdentifier, id: id, rect: rect)
    }
    return nil
}
func cgRect(_ id: CGWindowID) -> CGRect? {
    guard let rows = allRows() else { return nil }
    for row in rows {
        guard (row[kCGWindowNumber as String] as? CGWindowID) == id,
              let dict = row[kCGWindowBounds as String] as? [String: Any],
              let rect = CGRect(dictionaryRepresentation: dict as CFDictionary) else { continue }
        return rect
    }
    return nil
}
func screens() -> [CGRect] {
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &count) == .success else { return [] }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
    return ids.prefix(Int(count)).filter { CGDisplayMirrorsDisplay($0) == kCGNullDirectDisplay }.map(CGDisplayBounds)
}

func axFocusedWindow(_ pid: pid_t) -> AXUIElement? {
    let app = AXUIElementCreateApplication(pid)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
          let win = value else { return nil }
    return (win as! AXUIElement)
}
func axRect(_ element: AXUIElement) -> CGRect? {
    var p: CFTypeRef?, s: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &p) == .success,
          AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &s) == .success,
          let pv = p, let sv = s else { return nil }
    var pt = CGPoint.zero, sz = CGSize.zero
    guard AXValueGetValue(pv as! AXValue, .cgPoint, &pt), AXValueGetValue(sv as! AXValue, .cgSize, &sz) else { return nil }
    return CGRect(origin: pt, size: sz)
}
func axFullScreen(_ element: AXUIElement) -> Bool {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, "AXFullScreen" as CFString, &value) == .success else { return false }
    return (value as? Bool) ?? false
}
func within(_ a: CGRect, _ b: CGRect, _ tolerance: CGFloat) -> Bool {
    abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance &&
    abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
}
/// Corrective fallback only: set position, then size.
func axCorrect(_ window: AXUIElement, target: CGRect) {
    var origin = target.origin
    if let v = AXValueCreate(.cgPoint, &origin) { _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, v) }
    var size = target.size
    if let v = AXValueCreate(.cgSize, &size) { _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, v) }
}

let BTTCLI = "/Applications/BetterTouchTool.app/Contents/SharedSupport/bin/bttcli"
let SOCKET = "/tmp/com.hegenberg.BetterTouchTool.sock"

func dispatch(_ target: CGRect) -> String {
    let json = payload(target)
    if FileManager.default.fileExists(atPath: SOCKET) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: BTTCLI)
        process.arguments = ["trigger_action", "json=" + json]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 { return "socket" }
        } catch {}
    }
    let escaped = json.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", "tell application \"BetterTouchTool\" to trigger_action \"" + escaped + "\""]
    process.standardOutput = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
    return "applescript"
}
func waitFor(_ id: CGWindowID, target: CGRect, timeout: Double) -> CGRect? {
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    while true {
        if let r = cgRect(id), within(r, target, 4) { return r }
        if ProcessInfo.processInfo.systemUptime >= deadline { return cgRect(id) }
        usleep(5_000)
    }
}
func emit(_ value: Any) {
    let data = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    print(String(data: data, encoding: .utf8)!)
}
func logDispatch(_ value: [String: Any]) {
    let path = NSString(string: "~/.cache/sketchybar/2026-11-01-display-transfer-last.json").expandingTildeInPath
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}

let args = CommandLine.arguments
if args.contains("--self-test") {
    let ds = [CGRect(x: 0, y: 0, width: 1800, height: 1169), CGRect(x: -2560, y: -160, width: 2560, height: 1440)]
    var cases = 0
    for source in 0..<2 {
        for direction in ["left", "right"] {
            for tile in layouts(ds[source]) {
                let result = plan(tile.rect, ds, direction)!
                let expected = layouts(ds[1-source]).first { $0.name == tile.name }!
                assert(result.name == expected.name && result.rect == expected.rect)
                let actions = ["BTTActionsToExecute": [action(result.rect)]] as [String: Any]
                let list = actions["BTTActionsToExecute"] as! [[String: Any]]
                assert(list.count == 1 && list[0]["BTTPredefinedActionType"] as? Int == 446)
                cases += 1
            }
        }
        let r = workArea(ds[source])
        let free = CGRect(x: r.minX+r.width*0.17, y: r.minY+r.height*0.12, width:r.width*0.42, height:r.height*0.63)
        let back = plan(plan(free,ds,"left")!.rect,ds,"right")!.rect
        assert(abs(back.minX-free.minX) < 0.01 && abs(back.width-free.width) < 0.01)
    }
    assert(plan(ds[0], [ds[0]], "left") == nil)
    emit(["tile_cases": cases, "free_round_trips": 2, "single_action": 446, "result":"pass"])
    exit(0)
}

let began = ProcessInfo.processInfo.systemUptime
let direction = args.contains("left") ? "left" : "right"
guard let before = snapshot(), let target = plan(before.rect, screens(), direction) else { exit(0) }
if args.contains("--plan") {
    emit(["layout": target.name, "source_rect": [before.rect.minX,before.rect.minY,before.rect.width,before.rect.height],
          "target_rect":[target.rect.minX,target.rect.minY,target.rect.width,target.rect.height],
          "read_and_plan_ms":(ProcessInfo.processInfo.systemUptime-began)*1000,"actions":["BTTActionsToExecute": [action(target.rect)]]])
    exit(0)
}
if let win = axFocusedWindow(before.pid), axFullScreen(win) { exit(0) }
guard args.count == 2, ["left","right"].contains(args[1]) else { exit(0) }
guard let latest = snapshot(), latest.pid == before.pid, latest.id == before.id, latest.rect == before.rect else { exit(0) }

let method = dispatch(target.rect)
var final = cgRect(before.id) ?? before.rect
var corrected = false
if !within(final, target.rect, 4), let win = axFocusedWindow(before.pid) {
    corrected = true
    axCorrect(win, target: target.rect)
    usleep(20_000)
    final = cgRect(before.id) ?? final
}
let ms = (ProcessInfo.processInfo.systemUptime - began) * 1000
logDispatch(["method": method, "corrected": corrected, "layout": target.name, "ms": ms,
             "source": [before.rect.minX, before.rect.minY, before.rect.width, before.rect.height],
             "target": [target.rect.minX, target.rect.minY, target.rect.width, target.rect.height],
             "final": [final.minX, final.minY, final.width, final.height],
             "pid": Int(before.pid)])
exit(0)
