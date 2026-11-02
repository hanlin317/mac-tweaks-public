import AppKit
import CoreGraphics
import Darwin
import Foundation

// --check and --self-test never change the desktop.
enum Action: Equatable { case native, sketchybar }
struct EdgePolicy {
    var nativeVisible = false
    var returnSince: TimeInterval?
    mutating func step(distance: CGFloat, menuHeight: CGFloat, trackingMenu: Bool, pressed: Bool, now: TimeInterval) -> Action? {
        if !nativeVisible {
            if distance <= 1 { nativeVisible = true; returnSince = nil; return .native }
        } else if distance > menuHeight + 2 && !trackingMenu && !pressed {
            if returnSince == nil { returnSince = now }
            if now - returnSince! >= 0.02 { nativeVisible = false; returnSince = nil; return .sketchybar }
        } else { returnSince = nil }
        return nil
    }
}
func isNativeMenuCandidate(level: Int, ownerPID: Int32, barPID: Int32?, bounds: CGRect, screens: [CGRect]) -> Bool {
    guard ownerPID != barPID,
          level >= Int(CGWindowLevelForKey(.popUpMenuWindow)),
          level < Int(CGWindowLevelForKey(.screenSaverWindow)),
          bounds.width > 1, bounds.height > 1 else { return false }
    return screens.contains { $0.intersects(bounds) }
}
struct NativeMenu {
    typealias Connection = @convention(c) () -> Int32
    typealias Override = @convention(c) (Int32, Int32, Bool) -> Void
    typealias Alpha = @convention(c) (Int32, Double, Double, Float) -> Void
    let connection: Connection
    let override: Override
    let alpha: Alpha
    init?() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let c = dlsym(handle, "SLSMainConnectionID"),
              let o = dlsym(handle, "SLSSetMenuBarVisibilityOverrideOnDisplay"),
              let a = dlsym(handle, "SLSSetMenuBarInsetAndAlpha") else { return nil }
        connection = unsafeBitCast(c, to: Connection.self)
        override = unsafeBitCast(o, to: Override.self)
        alpha = unsafeBitCast(a, to: Alpha.self)
    }
    func hidden(_ hide: Bool) {
        let cid = connection()
        override(cid, 0, hide)
        alpha(cid, 0, 1, hide ? 0 : 1)
    }
}
func command(_ path: String, _ arguments: [String]) -> Bool {
    let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = arguments
    p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
    do { try p.run(); p.waitUntilExit(); return p.terminationStatus == 0 } catch { return false }
}
let args = CommandLine.arguments
if args.contains("--self-test") {
    var p = EdgePolicy()
    assert(p.step(distance: 18, menuHeight: 38, trackingMenu: false, pressed: true, now: 0) == nil)
    assert(p.step(distance: 0, menuHeight: 38, trackingMenu: false, pressed: false, now: 1) == .native)
    assert(p.step(distance: 20, menuHeight: 38, trackingMenu: false, pressed: false, now: 2) == nil)
    assert(p.step(distance: 150, menuHeight: 38, trackingMenu: true, pressed: false, now: 3) == nil)
    assert(p.step(distance: 150, menuHeight: 38, trackingMenu: false, pressed: true, now: 4) == nil)
    assert(p.step(distance: 100, menuHeight: 38, trackingMenu: false, pressed: false, now: 5) == nil)
    assert(p.step(distance: 100, menuHeight: 38, trackingMenu: false, pressed: false, now: 5.04) == .sketchybar)
    let display = CGRect(x: 0, y: 0, width: 1800, height: 1169)
    let popup = Int(CGWindowLevelForKey(.popUpMenuWindow))
    assert(!isNativeMenuCandidate(level: popup, ownerPID: 7, barPID: 7, bounds: CGRect(x: 20, y: 20, width: 220, height: 24), screens: [display]))
    assert(!isNativeMenuCandidate(level: popup, ownerPID: 8, barPID: 7, bounds: CGRect(x: -9999, y: -9999, width: 220, height: 24), screens: [display]))
    assert(!isNativeMenuCandidate(level: popup, ownerPID: 8, barPID: 7, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), screens: [display]))
    assert(isNativeMenuCandidate(level: popup, ownerPID: 8, barPID: 7, bounds: CGRect(x: 20, y: 20, width: 220, height: 240), screens: [display]))
    var quick = EdgePolicy(nativeVisible: true)
    assert(quick.step(distance: 41, menuHeight: 38, trackingMenu: false, pressed: false, now: 10) == nil)
    assert(quick.step(distance: 41, menuHeight: 38, trackingMenu: false, pressed: false, now: 10.04) == .sketchybar)
    print("PASS: clicks in bar stay in SketchyBar; only top 1pt reveals native; open menus and held clicks remain usable; return is debounced")
    exit(0)
}
guard let menu = NativeMenu() else { fputs("Required macOS menu-control symbols unavailable. No changes made.\n", stderr); exit(1) }
if args.contains("--check") { print("Required macOS menu-control symbols are available. No desktop changes made."); exit(0) }
// Service AppKit/WindowServer events on the main thread; dispatchMain alone does not.
let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
if args.contains("--event-loop-check") {
    Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in
        guard Thread.isMainThread else { exit(1) }
        print("PASS: AppKit event loop services the main-thread timer without desktop changes")
        exit(0)
    }
    application.run()
    exit(1)
}
struct DisplayRegion {
    let frame: CGRect
    let menuHeight: CGFloat
}
var displayRegions: [DisplayRegion] = []
var displayBounds: [CGRect] = []
func refreshDisplays() {
    let screens = NSScreen.screens
    let primaryTop = screens.first?.frame.maxY ?? 0
    let thickness = NSStatusBar.system.thickness
    displayRegions = screens.map { DisplayRegion(frame: $0.frame, menuHeight: max($0.safeAreaInsets.top, thickness)) }
    displayBounds = screens.map { CGRect(x: $0.frame.minX, y: primaryTop - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height) }
}
refreshDisplays()
let displayObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in refreshDisplays() }
let bar = "/opt/homebrew/bin/sketchybar"
func restore() {
    menu.hidden(false)
    _ = command(bar, ["--bar", "hidden=off"])
}
if args.contains("--restore") {
    // Stop only this exact coordinator executable, then restore ordinary native auto-hide.
    let executable = URL(fileURLWithPath: args[0]).standardizedFileURL.path
    _ = command("/usr/bin/pkill", ["-TERM", "-f", "^" + NSRegularExpression.escapedPattern(for: executable) + "$"])
    usleep(150000)
    restore(); exit(0)
}
// A single owner prevents multiple reloads from starting competing coordinators.
let cache = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache/sketchybar")
try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
let fd = open(cache.appendingPathComponent("2026-11-01-menu-coordinator.lock").path, O_CREAT | O_RDWR, 0o600)
guard fd >= 0 else { fputs("Cannot open coordinator lock. No desktop changes made.\n", stderr); exit(1) }
var acquired = false
for _ in 0..<10 {
    if flock(fd, LOCK_EX | LOCK_NB) == 0 { acquired = true; break }
    usleep(100000)
}
if !acquired { close(fd); exit(0) }
var policy = EdgePolicy()
var active = false
var misses = 0
var ticks = 0
func normalMode() {
    menu.hidden(true)
}
func trackingMenu() -> Bool {
    guard let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }
    // Inspect geometry, process IDs and layers only; no titles, images or keystrokes.
    let barPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.felixkratz.sketchybar").first?.processIdentifier
        ?? rows.first(where: { ($0[kCGWindowOwnerName as String] as? String) == "sketchybar" })?[kCGWindowOwnerPID as String] as? Int32
    // CGWindow bounds use a top-left origin, unlike NSScreen frames.
    return rows.contains { row in
        guard let level = row[kCGWindowLayer as String] as? Int,
              let pid = row[kCGWindowOwnerPID as String] as? Int32,
              let values = row[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: values as CFDictionary) else { return false }
        return isNativeMenuCandidate(level: level, ownerPID: pid, barPID: barPID, bounds: bounds, screens: displayBounds)
    }
}
let timer = DispatchSource.makeTimerSource(queue: .main)
timer.schedule(deadline: .now(), repeating: .milliseconds(20))
timer.setEventHandler {
    ticks += 1
    if ticks == 1 || ticks % 250 == 0 {
        let running = command("/usr/bin/pgrep", ["-x", "sketchybar"])
        if !running {
            misses += 1
            if active { restore(); active = false }
            if misses >= 2 { exit(0) }
            return
        }
        misses = 0
        if !active { policy = EdgePolicy(); active = true; normalMode() }
    }
    guard active else { return }
    let point = NSEvent.mouseLocation
    guard let screen = displayRegions.first(where: { $0.frame.insetBy(dx: -0.5, dy: -0.5).contains(point) }) else { return }
    let distance = screen.frame.maxY - point.y
    let height = screen.menuHeight
    let tracking = policy.nativeVisible && distance > height + 2 ? trackingMenu() : false
    if let action = policy.step(distance: distance, menuHeight: height, trackingMenu: tracking, pressed: NSEvent.pressedMouseButtons != 0, now: ProcessInfo.processInfo.systemUptime) {
        switch action {
        case .native:
            menu.hidden(false)
        case .sketchybar: normalMode()
        }
    }
}
signal(SIGTERM, SIG_IGN); signal(SIGINT, SIG_IGN)
let term = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
let intr = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
for source in [term, intr] { source.setEventHandler { restore(); exit(0) }; source.resume() }
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in if active { restore(); active = false } }
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in refreshDisplays(); ticks = 0 }
timer.resume()
application.run()
