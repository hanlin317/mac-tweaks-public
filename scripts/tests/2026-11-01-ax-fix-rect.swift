// Repair helper: move a specific AX window to an exact rect.
// usage: ax-fix-rect pid currentX currentY currentW currentH targetX targetY targetW targetH
import AppKit
import ApplicationServices
import Foundation

let a = CommandLine.arguments
guard a.count == 10, let pid = pid_t(a[1]),
      let cx = Double(a[2]), let cy = Double(a[3]), let cw = Double(a[4]), let ch = Double(a[5]),
      let tx = Double(a[6]), let ty = Double(a[7]), let tw = Double(a[8]), let th = Double(a[9]) else {
    print("usage: ax-fix-rect pid cx cy cw ch tx ty tw th")
    exit(2)
}

func attr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success else { return nil }
    return v
}
func rect(_ el: AXUIElement) -> CGRect? {
    guard let pv = attr(el, kAXPositionAttribute), CFGetTypeID(pv) == AXValueGetTypeID(),
          let sv = attr(el, kAXSizeAttribute), CFGetTypeID(sv) == AXValueGetTypeID() else { return nil }
    var p = CGPoint.zero, s = CGSize.zero
    guard AXValueGetValue(pv as! AXValue, .cgPoint, &p), AXValueGetValue(sv as! AXValue, .cgSize, &s) else { return nil }
    return CGRect(origin: p, size: s)
}
func set(_ el: AXUIElement, _ name: String, _ v: AXValue) {
    _ = AXUIElementSetAttributeValue(el, name as CFString, v)
}

let app = AXUIElementCreateApplication(pid)
guard let raw = attr(app, kAXWindowsAttribute), let windows = raw as? [AXUIElement] else {
    print("no windows"); exit(1)
}
let current = CGRect(x: cx, y: cy, width: cw, height: ch)
let target = CGRect(x: tx, y: ty, width: tw, height: th)
for el in windows {
    guard let r = rect(el), abs(r.minX - current.minX) <= 6, abs(r.minY - current.minY) <= 6,
          abs(r.width - current.width) <= 6, abs(r.height - current.height) <= 6 else { continue }
    for pass in 0..<2 {
        var p = target.origin
        if let v = AXValueCreate(.cgPoint, &p) { set(el, kAXPositionAttribute, v) }
        var s = target.size
        if let v = AXValueCreate(.cgSize, &s) { set(el, kAXSizeAttribute, v) }
        if pass == 0 { usleep(20_000) }
    }
    usleep(50_000)
    if let r = rect(el) { print("target \(target) -> now \(r)") } else { print("moved, unreadable") }
    exit(0)
}
print("no matching window at \(current)")
exit(1)
