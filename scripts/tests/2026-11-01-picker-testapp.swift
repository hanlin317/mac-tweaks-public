import AppKit
import Foundation

// Self-contained app for picker tests. Three standard windows on the main
// display; window One is focused on launch.
let app = NSApplication.shared
app.setActivationPolicy(.regular)

let specs: [(String, NSRect)] = [
    ("Picker Test One", NSRect(x: 120, y: 120, width: 900, height: 620)),
    ("Picker Test Two", NSRect(x: 1080, y: 220, width: 680, height: 520)),
    ("Picker Test Three", NSRect(x: 380, y: 740, width: 760, height: 360)),
]
var windows: [NSWindow] = []
for (title, rect) in specs {
    let w = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .resizable],
                     backing: .buffered, defer: false)
    w.title = title
    w.isReleasedWhenClosed = false
    w.makeKeyAndOrderFront(nil)
    windows.append(w)
}
windows.first?.makeKey()
NSRunningApplication.current.activate()
app.run()
