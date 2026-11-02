// Test-only: make a specific app frontmost via the public Accessibility API.
import AppKit
import ApplicationServices
import Foundation
let a = CommandLine.arguments
guard a.count == 2, let pid = pid_t(a[1]) else { print("usage: ax-front pid"); exit(2) }
let app = AXUIElementCreateApplication(pid)
let err = AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
usleep(250_000)
let front = NSWorkspace.shared.frontmostApplication
print("set=\(err.rawValue) front=\(front?.localizedName ?? "?")/\(front?.processIdentifier ?? 0)")
