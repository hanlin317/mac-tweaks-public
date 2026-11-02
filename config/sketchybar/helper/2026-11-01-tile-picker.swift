import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Darwin

// Half-window companion picker.
//
// 1. Snap the focused window to the requested half of its display.
// 2. Show a compact list of the other windows on that display.
// 3. Snap the chosen window into the opposite half.
//
// Geometry matches the installed display-transfer helper: 5 pt side/bottom
// margin, 43 pt top inset, 5 pt gap between paired halves.

let GAP: CGFloat = 5
let DIRS = ["left", "right", "top", "bottom"]

func workArea(_ s: CGRect) -> CGRect {
    CGRect(x: s.minX + 5, y: s.minY + 43, width: s.width - 10, height: s.height - 48)
}
func opposite(_ d: String) -> String {
    switch d {
    case "left": return "right"
    case "right": return "left"
    case "top": return "bottom"
    default: return "top"
    }
}
func slotRect(_ display: CGRect, _ d: String) -> CGRect {
    let r = workArea(display)
    switch d {
    case "left":
        let w = (r.width - GAP) / 2
        return CGRect(x: r.minX, y: r.minY, width: w, height: r.height)
    case "right":
        let w = (r.width - GAP) / 2
        return CGRect(x: r.maxX - w, y: r.minY, width: w, height: r.height)
    case "top":
        let h = (r.height - GAP) / 2
        return CGRect(x: r.minX, y: r.minY, width: r.width, height: h)
    default:
        let h = (r.height - GAP) / 2
        return CGRect(x: r.minX, y: r.maxY - h, width: r.width, height: h)
    }
}
let FRACTIONS: [CGFloat] = [0.5, 2.0 / 3.0, 1.0 / 3.0]

func fractionRect(_ display: CGRect, _ side: String, _ fraction: CGFloat) -> CGRect {
    let r = workArea(display)
    let w = (r.width - GAP) * fraction
    let x = side == "left" ? r.minX : r.maxX - w
    return CGRect(x: x, y: r.minY, width: w, height: r.height)
}
func anchoredFraction(_ rect: CGRect, _ display: CGRect, _ side: String) -> CGFloat? {
    let r = workArea(display)
    guard abs(rect.minY - r.minY) <= 8, abs(rect.height - r.height) <= 8 else { return nil }
    let usable = r.width - GAP
    for f in FRACTIONS where abs(rect.width - usable * f) <= 8 {
        if side == "left", abs(rect.minX - r.minX) <= 8 { return f }
        if side == "right", abs(rect.maxX - r.maxX) <= 8 { return f }
    }
    return nil
}
func nextFraction(_ f: CGFloat) -> CGFloat {
    if abs(f - 0.5) < 0.02 { return 2.0 / 3.0 }
    if abs(f - 2.0 / 3.0) < 0.02 { return 1.0 / 3.0 }
    return 0.5
}

func within(_ a: CGRect, _ b: CGRect, _ tolerance: CGFloat) -> Bool {
    abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance &&
    abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
}
func overlapArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
    let r = a.intersection(b)
    return r.isNull ? 0 : r.width * r.height
}

// MARK: - Displays

func screenBounds() -> [CGRect] {
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &count) == .success else { return [] }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
    return ids.prefix(Int(count))
        .filter { CGDisplayMirrorsDisplay($0) == kCGNullDirectDisplay }
        .map(CGDisplayBounds)
}
func bestDisplay(for rect: CGRect, _ screens: [CGRect]) -> CGRect? {
    guard !screens.isEmpty else { return nil }
    if let best = screens.max(by: { overlapArea(rect, $0) < overlapArea(rect, $1) }),
       overlapArea(rect, best) > 0 {
        return best
    }
    let c = CGPoint(x: rect.midX, y: rect.midY)
    return screens.min(by: {
        hypot($0.midX - c.x, $0.midY - c.y) < hypot($1.midX - c.x, $1.midY - c.y)
    })
}

// MARK: - Accessibility

func axAttr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(el, name as CFString, &value) == .success else { return nil }
    return value
}
func axString(_ el: AXUIElement, _ name: String) -> String? {
    axAttr(el, name) as? String
}
func axBool(_ el: AXUIElement, _ name: String) -> Bool {
    (axAttr(el, name) as? Bool) ?? false
}
func axRect(_ el: AXUIElement) -> CGRect? {
    guard let pv = axAttr(el, kAXPositionAttribute), CFGetTypeID(pv) == AXValueGetTypeID(),
          let sv = axAttr(el, kAXSizeAttribute), CFGetTypeID(sv) == AXValueGetTypeID() else { return nil }
    var p = CGPoint.zero, s = CGSize.zero
    guard AXValueGetValue(pv as! AXValue, .cgPoint, &p),
          AXValueGetValue(sv as! AXValue, .cgSize, &s) else { return nil }
    return CGRect(origin: p, size: s)
}
func axSet(_ el: AXUIElement, _ name: String, _ value: AXValue) {
    _ = AXUIElementSetAttributeValue(el, name as CFString, value)
}
func axMove(_ el: AXUIElement, to target: CGRect) {
    // Two passes: some apps clamp the first size change because the position
    // has not been applied yet.
    for pass in 0..<2 {
        var p = target.origin
        if let v = AXValueCreate(.cgPoint, &p) { axSet(el, kAXPositionAttribute, v) }
        var s = target.size
        if let v = AXValueCreate(.cgSize, &s) { axSet(el, kAXSizeAttribute, v) }
        if pass == 0 { usleep(12_000) }
    }
}
func axFullScreen(_ el: AXUIElement) -> Bool {
    axBool(el, "AXFullScreen")
}
func appElement(_ pid: pid_t) -> AXUIElement {
    AXUIElementCreateApplication(pid)
}
func focusedWindow(_ pid: pid_t) -> AXUIElement? {
    guard let v = axAttr(appElement(pid), kAXFocusedWindowAttribute) else { return nil }
    return (v as! AXUIElement)
}
func axWindows(_ pid: pid_t) -> [AXUIElement] {
    guard let v = axAttr(appElement(pid), kAXWindowsAttribute) else { return [] }
    return (v as? [AXUIElement]) ?? []
}
func axRaise(_ el: AXUIElement) {
    _ = AXUIElementPerformAction(el, kAXRaiseAction as CFString)
}

// MARK: - Windows

struct CGRow {
    let pid: pid_t
    let id: CGWindowID
    let rect: CGRect
    let owner: String
}
func cgRows() -> [CGRow] {
    guard let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                kCGNullWindowID) as? [[String: Any]] else { return [] }
    var out: [CGRow] = []
    for row in rows {
        guard let pid = row[kCGWindowOwnerPID as String] as? pid_t,
              let layer = row[kCGWindowLayer as String] as? Int, layer == 0,
              let id = row[kCGWindowNumber as String] as? CGWindowID,
              let dict = row[kCGWindowBounds as String] as? [String: Any],
              let rect = CGRect(dictionaryRepresentation: dict as CFDictionary),
              rect.width >= 120, rect.height >= 90 else { continue }
        let owner = row[kCGWindowOwnerName as String] as? String ?? ""
        out.append(CGRow(pid: pid, id: id, rect: rect, owner: owner))
    }
    return out
}
func cgRect(_ id: CGWindowID) -> CGRect? {
    cgRows().first(where: { $0.id == id })?.rect
}
struct AXInfo {
    let element: AXUIElement
    let rect: CGRect
    let title: String
}
func axWindowInfos(_ pid: pid_t) -> [AXInfo] {
    var out: [AXInfo] = []
    for el in axWindows(pid) {
        guard axString(el, kAXRoleAttribute) == kAXWindowRole,
              axString(el, kAXSubroleAttribute) == kAXStandardWindowSubrole,
              !axBool(el, kAXMinimizedAttribute),
              !axFullScreen(el),
              let r = axRect(el), r.width >= 120, r.height >= 90 else { continue }
        let title = axString(el, kAXTitleAttribute) ?? ""
        out.append(AXInfo(element: el, rect: r, title: title))
    }
    return out
}

// MARK: - BTT dispatch

var currentActiveLabel = "?"

let BTTCLI = "/Applications/BetterTouchTool.app/Contents/SharedSupport/bin/bttcli"
let SOCKET = "/tmp/com.hegenberg.BetterTouchTool.sock"

func action(_ r: CGRect) -> [String: Any] {
    let x = Int(r.minX.rounded()), y = Int(r.minY.rounded())
    let w = Int(r.width.rounded()), h = Int(r.height.rounded())
    return ["BTTPredefinedActionType": 446, "BTTGenericActionConfig": "\(x),\(y),\(w),\(h)"]
}
func dispatch(_ r: CGRect) -> String {
    let data = try! JSONSerialization.data(withJSONObject: ["BTTActionsToExecute": [action(r)]],
                                           options: [.sortedKeys])
    let json = String(data: data, encoding: .utf8)!
    if FileManager.default.fileExists(atPath: SOCKET) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: BTTCLI)
        p.arguments = ["trigger_action", "json=" + json]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            if p.terminationStatus == 0 { return "btt-socket" }
        } catch {}
    }
    let escaped = json.replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "\"", with: "\\\"")
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = ["-e", "tell application \"BetterTouchTool\" to trigger_action \"" + escaped + "\""]
    p.standardOutput = FileHandle.nullDevice
    do { try p.run(); p.waitUntilExit() } catch {}
    return "btt-applescript"
}
func waitFor(_ id: CGWindowID, _ target: CGRect, _ timeout: Double) -> CGRect? {
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    while true {
        if let r = cgRect(id), within(r, target, 5) { return r }
        if ProcessInfo.processInfo.systemUptime >= deadline { return cgRect(id) }
        usleep(5_000)
    }
}

// MARK: - Logging

func log(_ value: [String: Any]) {
    var v = value
    v["active_app"] = currentActiveLabel
    v["at"] = ISO8601DateFormatter().string(from: Date())
    let path = NSString(string: "~/.cache/sketchybar/2026-11-01-tile-picker-last.json").expandingTildeInPath
    if let data = try? JSONSerialization.data(withJSONObject: v, options: [.sortedKeys]) {
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}

// MARK: - Picker UI

struct Candidate {
    let pid: pid_t
    let id: CGWindowID
    let title: String
    let appName: String
    let icon: NSImage
    let rect: CGRect
    let element: AXUIElement
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class KeyTable: NSTableView {
    var keyHandler: ((NSEvent) -> Bool)?
    override func keyDown(with event: NSEvent) {
        if keyHandler?(event) == true { return }
        super.keyDown(with: event)
    }
}

final class CandidateCell: NSTableCellView {
    let iconView = NSImageView()
    let titleField = NSTextField(labelWithString: "")
    let appField = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        titleField.font = .systemFont(ofSize: 13, weight: .medium)
        titleField.lineBreakMode = .byTruncatingTail
        titleField.textColor = .labelColor
        appField.font = .systemFont(ofSize: 10.5, weight: .regular)
        appField.lineBreakMode = .byTruncatingTail
        appField.textColor = .secondaryLabelColor
        for v in [iconView, titleField, appField] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            titleField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleField.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            appField.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
            appField.trailingAnchor.constraint(equalTo: titleField.trailingAnchor),
            appField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 1),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(_ c: Candidate) {
        iconView.image = c.icon
        titleField.stringValue = c.title.isEmpty ? "\(c.appName) window" : c.title
        appField.stringValue = c.appName
    }
}

final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PickerController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private let panel: PickerPanel
    private let effect = NSVisualEffectView()
    private let container = FlippedView()
    private let header = NSTextField(labelWithString: "")
    private let footer = NSTextField(labelWithString: "")
    private let scroll = NSScrollView()
    private let table = KeyTable()
    private let candidates: [Candidate]
    private let direction: String
    private let onFinish: (Candidate?) -> Void
    private var finished = false
    private var dismissTimer: Timer?

    init(candidates: [Candidate], direction: String, frame: NSRect,
         onFinish: @escaping (Candidate?) -> Void) {
        self.candidates = candidates
        self.direction = direction
        self.onFinish = onFinish
        self.panel = PickerPanel(contentRect: frame,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        super.init()
        build(frame: frame)
    }

    private func build(frame: NSRect) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.appearance = NSAppearance(named: .darkAqua)
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true
        panel.contentView = effect

        container.frame = NSRect(origin: .zero, size: frame.size)
        container.autoresizingMask = [.width, .height]
        effect.addSubview(container)

        let width = frame.width
        let visible = min(max(candidates.count, 1), 6)
        let listHeight = CGFloat(visible) * 44 + 2

        header.stringValue = "Choose a window for the \(direction) half"
        header.font = .systemFont(ofSize: 12.5, weight: .semibold)
        header.textColor = .labelColor
        header.lineBreakMode = .byTruncatingTail
        header.frame = NSRect(x: 14, y: 9, width: width - 28, height: 18)
        container.addSubview(header)

        table.dataSource = self
        table.delegate = self
        table.headerView = nil
        table.backgroundColor = .clear
        table.rowHeight = 42
        table.intercellSpacing = NSSize(width: 0, height: 2)
        table.selectionHighlightStyle = .regular
        table.allowsEmptySelection = false
        table.focusRingType = .none
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.width = width - 12
        table.addTableColumn(column)
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.action = #selector(rowClicked)
        table.target = self
        table.keyHandler = { [weak self] event in
            self?.handleKey(event) ?? false
        }

        scroll.frame = NSRect(x: 6, y: 34, width: width - 12, height: listHeight)
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = candidates.count > visible
        scroll.scrollerStyle = .overlay
        scroll.autohidesScrollers = true
        scroll.documentView = table
        scroll.contentView.postsBoundsChangedNotifications = true
        container.addSubview(scroll)

        let tableHeight = CGFloat(candidates.count) * 44
        table.frame = NSRect(x: 0, y: 0, width: width - 12, height: tableHeight)

        footer.stringValue = "↑↓ select      ↵ tile      esc cancel"
        footer.font = .systemFont(ofSize: 10.5, weight: .regular)
        footer.textColor = .secondaryLabelColor
        footer.frame = NSRect(x: 14, y: 34 + listHeight + 5, width: width - 28, height: 14)
        container.addSubview(footer)

        if !candidates.isEmpty {
            table.selectRowIndexes([0], byExtendingSelection: false)
        }
    }

    func show() {
        panel.setFrame(panel.frame, display: true)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(table)
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            self?.finish(nil)
        }
        if let t = dismissTimer { RunLoop.main.add(t, forMode: .common) }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { candidates.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("candidate")
        let cell: CandidateCell
        if let existing = tableView.makeView(withIdentifier: id, owner: self) as? CandidateCell {
            cell = existing
        } else {
            cell = CandidateCell(frame: .zero)
            cell.identifier = id
        }
        cell.configure(candidates[row])
        return cell
    }

    @objc private func rowClicked() {
        let row = table.clickedRow
        guard row >= 0, row < candidates.count else { return }
        finish(candidates[row])
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53:
            finish(nil); return true
        case 36, 76:
            let row = table.selectedRow
            if row >= 0, row < candidates.count { finish(candidates[row]) }
            return true
        case 125, 48:
            move(1); return true
        case 126:
            move(-1); return true
        case 123:
            return true
        case 124:
            return true
        default:
            if let ch = event.charactersIgnoringModifiers, ch.count == 1,
               let n = Int(ch), n >= 1, n <= candidates.count {
                finish(candidates[n - 1]); return true
            }
            return false
        }
    }
    private func move(_ delta: Int) {
        guard !candidates.isEmpty else { return }
        let count = candidates.count
        let current = table.selectedRow
        let next = current < 0 ? 0 : (current + delta + count) % count
        table.selectRowIndexes([next], byExtendingSelection: false)
        table.scrollRowToVisible(next)
    }

    private func finish(_ chosen: Candidate?) {
        guard !finished else { return }
        finished = true
        dismissTimer?.invalidate()
        panel.orderOut(nil)
        onFinish(chosen)
    }
}

// MARK: - Panel placement

func appKitFrame(topLeftCG top: CGPoint, size: CGSize) -> NSRect {
    let mainMaxY = NSScreen.screens.first(where: { $0.frame.minX == 0 && $0.frame.minY == 0 })?.frame.maxY
        ?? NSScreen.main?.frame.maxY ?? 0
    return NSRect(x: top.x, y: mainMaxY - top.y - size.height,
                  width: size.width, height: size.height)
}

// MARK: - Single instance

var singleInstanceFD: Int32 = -1

/// Only one picker may be visible. A new gesture takes over: the previous
/// instance is terminated so panels cannot stack.
func acquireSingleInstance() -> Bool {
    let path = NSString(string: "~/.cache/sketchybar/2026-11-01-tile-picker.lock").expandingTildeInPath
    let fd = open(path, O_CREAT | O_RDWR, 0o600)
    guard fd >= 0 else { return true }
    if flock(fd, LOCK_EX | LOCK_NB) != 0 {
        lseek(fd, 0, SEEK_SET)
        let data = FileHandle(fileDescriptor: fd, closeOnDealloc: false).readDataToEndOfFile()
        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let pid = pid_t(text), pid > 0 {
            kill(pid, SIGTERM)
        }
        usleep(120_000)
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            return false
        }
    }
    ftruncate(fd, 0)
    lseek(fd, 0, SEEK_SET)
    let line = "\(getpid())\n"
    _ = line.withCString { write(fd, $0, strlen($0)) }
    singleInstanceFD = fd
    return true
}

// MARK: - Main

struct Options {
    var direction: String?
    var autoPick: Int?
    var pid: pid_t?
    var onlyPid = false
    var already = false
    var cycleIfHalf = false
    var listOnly = false
    var selfTest = false
}

func parseOptions() -> Options {
    var o = Options()
    let a = CommandLine.arguments
    if a.contains("--self-test") { o.selfTest = true }
    if a.contains("--list") { o.listOnly = true }
    if a.contains("--only-pid") { o.onlyPid = true }
    if a.contains("--already") { o.already = true }
    if a.contains("--cycle-if-half") { o.cycleIfHalf = true }
    for (i, arg) in a.enumerated() where arg == "--auto" && i + 1 < a.count {
        o.autoPick = Int(a[i + 1])
    }
    for (i, arg) in a.enumerated() where arg == "--pid" && i + 1 < a.count {
        o.pid = pid_t(a[i + 1])
    }
    if let first = a.dropFirst().first(where: { DIRS.contains($0) }) {
        o.direction = first
    }
    return o
}

func selfTest() {
    let displays = [
        CGRect(x: 0, y: 0, width: 1800, height: 1169),
        CGRect(x: -2560, y: -160, width: 2560, height: 1440),
    ]
    var cases = 0
    for d in displays {
        let w = workArea(d)
        for dir in DIRS {
            let s = slotRect(d, dir), c = slotRect(d, opposite(dir))
            assert(s.intersection(c).isNull || overlapArea(s, c) == 0)
            switch dir {
            case "left", "right":
                assert(abs(s.width + c.width + GAP - w.width) < 0.01)
                assert(abs(s.height - w.height) < 0.01 && abs(c.height - w.height) < 0.01)
                assert(abs(s.minX - (dir == "left" ? w.minX : w.maxX - s.width)) < 0.01)
            default:
                assert(abs(s.height + c.height + GAP - w.height) < 0.01)
                assert(abs(s.width - w.width) < 0.01 && abs(c.width - w.width) < 0.01)
            }
            assert(within(workArea(d).union(s.union(c)), workArea(d), GAP + 0.01))
            cases += 1
        }
    }
    var fractions = 0
    for d in displays {
        for side in ["left", "right"] {
            for f in FRACTIONS {
                let r = fractionRect(d, side, f)
                assert(anchoredFraction(r, d, side) == f)
                if f == 0.5 { assert(within(r, slotRect(d, side), 0.01)) }
                fractions += 1
            }
        }
    }
    print("{\"geometry_cases\":\(cases),\"fraction_cases\":\(fractions),\"gap\":\(Int(GAP)),\"result\":\"pass\"}")
}

func describe(_ c: Candidate) -> [String: Any] {
    ["pid": Int(c.pid), "id": Int(c.id), "title": c.title, "app": c.appName,
     "rect": [c.rect.minX, c.rect.minY, c.rect.width, c.rect.height]]
}

func nowStamp() -> String { ISO8601DateFormatter().string(from: Date()) }

func appendStart(_ line: String) {
    if let data = line.data(using: .utf8) {
        let path = NSString(string: "~/.cache/sketchybar/2026-11-01-tile-picker-starts.log").expandingTildeInPath
        if let fh = FileHandle(forWritingAtPath: path) { fh.seekToEndOfFile(); fh.write(data); fh.closeFile() }
        else { try? data.write(to: URL(fileURLWithPath: path)) }
    }
}

func run() {
    let opts = parseOptions()
    if opts.selfTest { selfTest(); exit(0) }

    guard let direction = opts.direction else {
        FileHandle.standardError.write("usage: tile-picker left|right|top|bottom [--already] [--cycle-if-half] [--auto N] [--pid N] [--only-pid] [--list]\n".data(using: .utf8)!)
        exit(2)
    }
    guard acquireSingleInstance() else { exit(0) }
    let began = ProcessInfo.processInfo.systemUptime
    let screens = screenBounds()
    let forcedPid = opts.pid
    let activePid: pid_t
    if let forcedPid {
        activePid = forcedPid
    } else {
        guard let front = NSWorkspace.shared.frontmostApplication else { exit(opts.cycleIfHalf ? 3 : 0) }
        activePid = front.processIdentifier
    }
    let frontName = NSRunningApplication(processIdentifier: activePid)?.localizedName ?? "?"
    currentActiveLabel = "\(frontName)/\(activePid)"
    let stamp = ISO8601DateFormatter().string(from: Date())
    if !opts.cycleIfHalf {
        appendStart("\(stamp) pid=\(getpid()) ppid=\(getppid()) mode=picker arg=\(direction) active=\(frontName)/\(activePid) locked=\(singleInstanceFD >= 0)\n")
    }
    let activeElement = focusedWindow(activePid) ?? (forcedPid != nil ? axWindows(activePid).first : nil)
    // Native full-screen windows are not part of the tiling space.
    if let el = activeElement, axFullScreen(el) { exit(0) }
    let initialRect: CGRect
    if let r = activeElement.flatMap(axRect) {
        initialRect = r
    } else if let r = cgRows().first(where: { $0.pid == activePid })?.rect {
        initialRect = r
    } else {
        exit(opts.cycleIfHalf ? 3 : 0)
    }
    var activeRect = initialRect
    guard let display = bestDisplay(for: initialRect, screens) else { exit(opts.cycleIfHalf ? 3 : 0) }

    let target = slotRect(display, direction)
    // When BTT's own resize action already ran, give it a moment to settle
    // before deciding whether a corrective move is needed.
    if opts.already {
        let deadline = ProcessInfo.processInfo.systemUptime + 0.35
        while ProcessInfo.processInfo.systemUptime < deadline {
            if let el = activeElement, let r = axRect(el), within(r, target, 8) {
                activeRect = r
                break
            }
            usleep(10_000)
        }
    }
    let activeStart = activeRect
    let complement = slotRect(display, opposite(direction))

    let activeID = cgRows().first { $0.pid == activePid && within($0.rect, activeStart, 4) }?.id

    // Cycle the width of a window that is already docked to this side:
    // 1/2 -> 2/3 -> 1/3 -> 1/2. No companion panel for this path.
    if opts.cycleIfHalf {
        guard direction == "left" || direction == "right" else { exit(3) }
        guard let from = anchoredFraction(activeStart, display, direction) else { exit(3) }
        let to = nextFraction(from)
        appendStart("\(nowStamp()) pid=\(getpid()) ppid=\(getppid()) mode=cycle arg=\(direction) from=\(String(format: "%.3f", from)) to=\(String(format: "%.3f", to)) active=\(frontName)/\(activePid)\n")
        let rect = fractionRect(display, direction, to)
        var method = "none"
        var final = activeStart
        if forcedPid != nil, let el = activeElement {
            axMove(el, to: rect)
            usleep(30_000)
            final = axRect(el) ?? activeStart
            method = "ax-test"
        } else if let id = activeID {
            method = dispatch(rect)
            final = waitFor(id, rect, 0.6) ?? activeStart
            if !within(final, rect, 5), let el = activeElement {
                axMove(el, to: rect)
                usleep(20_000)
                final = cgRect(id) ?? final
                method += "+ax"
            }
        } else if let el = activeElement {
            axMove(el, to: rect)
            usleep(30_000)
            final = axRect(el) ?? activeStart
            method = "ax"
        }
        log(["action": "cycle", "direction": direction,
             "from_fraction": from, "to_fraction": to,
             "display": [display.minX, display.minY, display.width, display.height],
             "target": [rect.minX, rect.minY, rect.width, rect.height],
             "final": [final.minX, final.minY, final.width, final.height],
             "method": method, "ms": (ProcessInfo.processInfo.systemUptime - began) * 1000])
        exit(0)
    }

    func candidatesNow() -> [Candidate] {
        let rows = cgRows()
        var infos: [pid_t: [AXInfo]] = [:]
        var used = Set<String>()
        var out: [Candidate] = []
        for row in rows {
            if row.pid == getpid() { continue }
            if opts.onlyPid, let only = opts.pid, row.pid != only { continue }
            if let aid = activeID, row.id == aid { continue }
            if row.rect.width < 160 || row.rect.height < 110 { continue }
            guard overlapArea(row.rect, display) > 0 else { continue }
            // Already exactly filling the slot we are about to hand out.
            if within(row.rect, complement, 8) { continue }
            // Already filling the half the active window occupies.
            if within(row.rect, target, 8) { continue }
            if infos[row.pid] == nil { infos[row.pid] = axWindowInfos(row.pid) }
            guard let infosForPid = infos[row.pid] else { continue }
            for info in infosForPid {
                let key = "\(row.pid)|\(Int(info.rect.minX))|\(Int(info.rect.minY))|\(Int(info.rect.width))|\(Int(info.rect.height))"
                if used.contains(key) { continue }
                guard within(info.rect, row.rect, 6) else { continue }
                used.insert(key)
                let appName = NSRunningApplication(processIdentifier: row.pid)?.localizedName ?? row.owner
                let icon = NSRunningApplication(processIdentifier: row.pid)?.icon
                    ?? NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
                    ?? NSImage()
                out.append(Candidate(pid: row.pid, id: row.id, title: info.title,
                                     appName: appName, icon: icon, rect: info.rect,
                                     element: info.element))
                break
            }
        }
        return out
    }

    if opts.listOnly {
        let list = candidatesNow().map(describe)
        let data = try! JSONSerialization.data(withJSONObject: list, options: [.sortedKeys])
        print(String(data: data, encoding: .utf8)!)
        exit(0)
    }

    // 1. Snap the focused window.
    var moveMethod = "none"
    var activeFinal = activeStart
    let activeAlready = activeElement.map { !axFullScreen($0) && within(activeStart, target, 8) } ?? false
    if !activeAlready {
        if forcedPid != nil, let el = activeElement {
            axMove(el, to: target)
            usleep(40_000)
            activeFinal = axRect(el) ?? activeStart
            moveMethod = "ax-test"
        } else if let id = activeID {
            moveMethod = dispatch(target)
            let got = waitFor(id, target, 0.6)
            activeFinal = got ?? activeStart
            if !within(activeFinal, target, 5), let el = activeElement {
                axMove(el, to: target)
                usleep(20_000)
                activeFinal = cgRect(id) ?? activeFinal
                moveMethod += "+ax"
            }
        } else if let el = activeElement {
            axMove(el, to: target)
            usleep(30_000)
            activeFinal = axRect(el) ?? activeStart
            moveMethod = "ax"
        }
    }

    // 2. Candidates, measured after the snap.
    let list = candidatesNow()
    if list.isEmpty {
        log(["action": "tile", "direction": direction, "display": [display.minX, display.minY, display.width, display.height],
             "slot": [target.minX, target.minY, target.width, target.height],
             "active": [activeStart.minX, activeStart.minY, activeStart.width, activeStart.height],
             "active_final": [activeFinal.minX, activeFinal.minY, activeFinal.width, activeFinal.height],
             "move": moveMethod, "candidates": 0, "chosen": NSNull(), "ms": (ProcessInfo.processInfo.systemUptime - began) * 1000])
        exit(0)
    }

    // 3. Headless test path.
    if let index = opts.autoPick, index >= 0, index < list.count {
        let chosen = list[index]
        var chooseMethod = "none"
        applyChoice(chosen, to: complement, chooseMethod: &chooseMethod)
        log(["action": "auto", "direction": direction,
             "display": [display.minX, display.minY, display.width, display.height],
             "slot": [target.minX, target.minY, target.width, target.height],
             "complement": [complement.minX, complement.minY, complement.width, complement.height],
             "active": [activeStart.minX, activeStart.minY, activeStart.width, activeStart.height],
             "active_final": [activeFinal.minX, activeFinal.minY, activeFinal.width, activeFinal.height],
             "move": moveMethod, "chosen_move": chooseMethod, "candidates": list.count,
             "chosen": describe(chosen), "chosen_index": index,
             "ms": (ProcessInfo.processInfo.systemUptime - began) * 1000])
        exit(0)
    }

    // 4. Interactive picker in the free half.
    let width = min(320, complement.width - 24)
    let visible = min(max(list.count, 1), 6)
    let height = 34 + CGFloat(visible) * 44 + 2 + 24
    let top = CGPoint(x: complement.midX - width / 2, y: complement.minY + 14)
    let frame = appKitFrame(topLeftCG: top, size: CGSize(width: width, height: height))

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    var chosenRef: Candidate?
    let controller = PickerController(candidates: list, direction: opposite(direction), frame: frame) { chosen in
        chosenRef = chosen
        if let chosen {
            var method = "none"
            applyChoice(chosen, to: complement, chooseMethod: &method)
            log(["action": "pick", "direction": direction,
                 "display": [display.minX, display.minY, display.width, display.height],
                 "slot": [target.minX, target.minY, target.width, target.height],
                 "complement": [complement.minX, complement.minY, complement.width, complement.height],
                 "active": [activeStart.minX, activeStart.minY, activeStart.width, activeStart.height],
                 "active_final": [activeFinal.minX, activeFinal.minY, activeFinal.width, activeFinal.height],
                 "first_move": moveMethod, "chosen": describe(chosen),
                 "chosen_final": [cgRect(chosen.id)?.minX ?? 0, cgRect(chosen.id)?.minY ?? 0,
                                  cgRect(chosen.id)?.width ?? 0, cgRect(chosen.id)?.height ?? 0],
                 "chosen_move": method, "candidates": list.count,
                 "ms": (ProcessInfo.processInfo.systemUptime - began) * 1000])
        } else {
            log(["action": "cancel", "direction": direction,
                 "slot": [target.minX, target.minY, target.width, target.height],
                 "active_final": [activeFinal.minX, activeFinal.minY, activeFinal.width, activeFinal.height],
                 "move": moveMethod, "candidates": list.count,
                 "ms": (ProcessInfo.processInfo.systemUptime - began) * 1000])
        }
        NSApp.hide(nil)
        if let chosen, let app = NSRunningApplication(processIdentifier: chosen.pid) {
            app.activate()
            axRaise(chosen.element)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { exit(0) }
    }
    _ = chosenRef
    _ = controller
    controller.show()
    app.run()
}

func applyChoice(_ chosen: Candidate, to rect: CGRect, chooseMethod: inout String) {
    // Prefer a direct AX move: it leaves the original window focused and works
    // on background windows. Fall back to activate + BTT 446 if the app clamps.
    axMove(chosen.element, to: rect)
    if let got = waitFor(chosen.id, rect, 0.35), within(got, rect, 6) {
        chooseMethod = "ax"
        return
    }
    if let app = NSRunningApplication(processIdentifier: chosen.pid) {
        app.activate()
    }
    axRaise(chosen.element)
    _ = AXUIElementSetAttributeValue(appElement(chosen.pid), kAXFocusedWindowAttribute as CFString, chosen.element)
    usleep(70_000)
    chooseMethod = dispatch(rect)
    let got = waitFor(chosen.id, rect, 0.7)
    if let got, !within(got, rect, 6) {
        axMove(chosen.element, to: rect)
        usleep(20_000)
        chooseMethod += "+ax"
    }
}

run()
