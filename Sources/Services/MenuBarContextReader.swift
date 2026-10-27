import AppKit
import ApplicationServices
import IslandCore

/// Event-driven, bounded geometry reads. Never reads menu titles or captures screen pixels.
@MainActor final class MenuBarContextReader {
    var onChange: (([CGRect]) -> Void)?
    private let worker = DispatchQueue(label: "com.notchislandsports.menu-geometry", qos: .utility)
    private var generation = 0
    private var backgroundWork: DispatchWorkItem?
    private var pending: DispatchWorkItem?
    private var observer: AXObserver?
    private var notifications: [NSObjectProtocol] = []
    private var lastPID: pid_t?
    private var active = false
    var excludedWindows = Set<CGWindowID>()
    private var lastFrames: [CGRect] = []

    func start() {
        guard !active else { return }
        active = true
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            notifications.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        refresh()
    }
    func stop() {
        active = false; generation += 1
        pending?.cancel(); pending = nil; backgroundWork?.cancel(); backgroundWork = nil
        detach()
        for token in notifications { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        notifications.removeAll()
    }
    private func detach() {
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        observer = nil
    }
    func refresh() {
        guard active else { return }
        pending?.cancel(); backgroundWork?.cancel()
        generation += 1
        let token = generation
        let task = DispatchWorkItem { [weak self] in
            guard let self, self.active, self.generation == token else { return }
            self.read(token: token)
        }
        pending = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: task)
    }
    private func read(token: Int) {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if let front, front != ownPID { lastPID = front }
        let pid = lastPID
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        let screens = NSScreen.screens.map { screen -> (CGRect, CGFloat, CGFloat) in
            let camera = screen.auxiliaryTopLeftArea?.maxX ?? screen.frame.midX - 90
            return (screen.frame, max(24, screen.safeAreaInsets.top), camera)
        }
        let excluded = excludedWindows
        let trusted = AXIsProcessTrusted()
        attach(pid: pid, trusted: trusted)
        let work = DispatchWorkItem { [weak self] in
            var frames: [CGRect] = []
            var menuKnown = false
            if trusted, let pid {
                let app = AXUIElementCreateApplication(pid)
                AXUIElementSetMessagingTimeout(app, 0.04)
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &value) == .success,
                   let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
                    let bar = unsafeBitCast(value, to: AXUIElement.self)
                    var children: CFTypeRef?
                    if AXUIElementCopyAttributeValue(bar, kAXChildrenAttribute as CFString, &children) == .success,
                       let items = children as? [AXUIElement] {
                        let deadline = ProcessInfo.processInfo.systemUptime + 0.35
                        var measured = 0
                        for item in items.prefix(32) {
                            guard ProcessInfo.processInfo.systemUptime < deadline else { break }
                            AXUIElementSetMessagingTimeout(item, 0.04)
                            if let rect = Self.bounds(item) {
                                frames.append(MenuBarPlacement.appKitRect(rect, mainDisplayTop: top)); measured += 1
                            }
                        }
                        menuKnown = measured == items.count && measured > 0
                    }
                }
            }
            let menuFrames = frames
            // Window bounds/layer remain usable without screen recording. Do not request window titles.
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
            for window in windows {
                guard let id = window[kCGWindowNumber as String] as? UInt32, !excluded.contains(id),
                      let layer = window[kCGWindowLayer as String] as? Int, layer >= 20,
                      let dictionary = window[kCGWindowBounds as String] as? NSDictionary,
                      let rect = CGRect(dictionaryRepresentation: dictionary as CFDictionary), rect.height > 0, rect.height <= 80 else { continue }
                let converted = MenuBarPlacement.appKitRect(rect, mainDisplayTop: top)
                if screens.contains(where: { screen, height, _ in
                    let band = CGRect(x: screen.minX, y: screen.maxY - height, width: screen.width, height: height)
                    return converted.intersects(band) && converted.width < screen.width * 0.75
                }) { frames.append(converted) }
            }
            for (screen, height, cameraLeft) in screens {
                // Unknown application menus are protected, never guessed to be empty.
                let band = CGRect(x: screen.minX, y: screen.maxY - height, width: screen.width, height: height)
                if !menuKnown || !menuFrames.contains(where: { $0.intersects(band) }) { frames.append(CGRect(x: screen.minX, y: screen.maxY - height, width: max(0, cameraLeft - screen.minX), height: height)) }
                // Reserve system status controls even when their geometry isn't exposed.
                frames.append(CGRect(x: screen.maxX - 240, y: screen.maxY - height, width: 240, height: height))
            }
            frames.sort { $0.minX == $1.minX ? $0.minY < $1.minY : $0.minX < $1.minX }
            let result = frames
            Task { @MainActor [weak self] in
                guard let self, self.active, self.generation == token else { return }
                if result != self.lastFrames { self.lastFrames = result; self.onChange?(result) }
            }
        }
        backgroundWork = work
        worker.async(execute: work)
    }
    private func attach(pid: pid_t?, trusted: Bool) {
        detach()
        guard trusted, let pid else { return }
        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, context in
            guard let context else { return }
            let reader = Unmanaged<MenuBarContextReader>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor [weak reader] in reader?.refresh() }
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.04)
        for name in [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification, kAXLayoutChangedNotification] {
            AXObserverAddNotification(created, app, name as CFString, Unmanaged.passUnretained(self).toOpaque())
        }
        observer = created
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
    }
    nonisolated private static func bounds(_ element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?, size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size, CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, dimensions = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(position, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeBitCast(size, to: AXValue.self), .cgSize, &dimensions),
              point.x.isFinite, point.y.isFinite, dimensions.width.isFinite, dimensions.height.isFinite, dimensions.width > 0, dimensions.height > 0 else { return nil }
        return CGRect(origin: point, size: dimensions)
    }
}
