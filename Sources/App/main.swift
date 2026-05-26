import AppKit

// NotchIslandSports — macOS Notch Live Sports Overlay
// Entry point: Creates NSApplication with custom AppDelegate

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
