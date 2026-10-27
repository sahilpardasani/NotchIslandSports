import AppKit
import SwiftUI
import IslandCore

@main struct NotchRender {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let data = SportsDataManager()
        data.isUsingMockData = true
        data.hasNotch = true; data.notchWidth = 180
        data.activeMatch = MockDataProvider.getMockMatches().first { $0.sportType == .cricket }
        let calendar = CalendarManager.visualFixture()
        let media = NowPlayingManager()
        media.currentTrack = NowPlayingTrack(title: "iOS 27.2 is Out! — What’s New and Everything You Need to Know", artist: "Synthetic fixture", album: "", duration: 180,
            elapsedTime: 30, isPlaying: true, artwork: nil, dominantColor: .purple, sourceBundleID: "com.apple.Music")
        let suite = "NotchRender." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, activity) in [("notch-three-activities", Optional<IslandActivity>.none), ("notch-media-primary", nil), ("notch-calendar-compact", nil), ("notch-artwork-pill", nil), ("notch-menu-crowded", nil), ("notch-score-fallback", nil), ("notch-score-merged", nil),
                                  ("notch-calendar-expanded", .calendar), ("notch-clock-expanded", .clock),
                                  ("notch-clock-paused", .clock), ("notch-clock-unavailable", .clock),
                                  ("notch-clock-multiple", .clock), ("notch-clock-empty", .clock),
                                  ("notch-approval-expanded", .approval), ("notch-chatgpt-approval", .approval), ("notch-approval-crowded", nil), ("notch-music-expanded", .music), ("notch-sports-expanded", .sports), ("notch-merged", nil)] {
            if name == "notch-artwork-pill" {
                let cover = NSImage(size: NSSize(width: 96, height: 96))
                cover.lockFocus()
                NSColor.systemTeal.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: 96, height: 96)).fill()
                NSColor.systemIndigo.setFill(); NSBezierPath(ovalIn: NSRect(x: 16, y: 16, width: 64, height: 64)).fill()
                NSColor.white.setFill(); NSBezierPath(ovalIn: NSRect(x: 40, y: 40, width: 16, height: 16)).fill()
                cover.unlockFocus()
                media.setArtworkFixture(cover)
            } else { media.setArtworkFixture(nil) }
            let approvalCrowded = name == "notch-approval-crowded"
            let scoreRegression = name.hasPrefix("notch-score-")
            data.activeMatch = scoreRegression ? .cricket(CricketMatch(id: "layout-regression", status: .unknown,
                homeTeam: "Sikkim", awayTeam: "Nagaland", homeTeamAbbrev: "SIKM", awayTeamAbbrev: "NAGA",
                homeScore: "184", awayScore: "187 & 46/4", statusText: ""))
                : MockDataProvider.getMockMatches().first { $0.sportType == .cricket }
            let clock = NativeClockManager.visualFixture(paused: name == "notch-clock-paused",
                controllable: name != "notch-clock-unavailable", count: name == "notch-clock-multiple" ? 3 : name == "notch-clock-empty" ? 0 : 1,
                remaining: name == "notch-clock-multiple" ? 3723 : 197)
            let presentation = IslandPresentation(defaults: defaults)
            presentation.cameraHeight = 32
            presentation.update(sports: true, music: true, clock: true, calendar: true, approval: approvalCrowded)
            if let activity { presentation.open(activity) }
            if name == "notch-media-primary" {
                presentation.update(sports: true, music: true, clock: false)
                presentation.promote(.music); presentation.collapse(); presentation.finishResize()
            }
            if name == "notch-calendar-compact" || name == "notch-artwork-pill" { presentation.cyclePrimary(forward: false) }
            let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
            let geometry = NotchGeometry.layout(screen: screen, safeTop: 32, leftArea: nil, rightArea: nil,
                expanded: activity != nil,
                contentHeight: activity == .approval ? 114 : activity == .calendar ? 420 : activity == .clock ? NativeClockView.contentHeight(timerCount: clock.timers.count) : activity == .music ? 180 : 320,
                expandedWidth: activity == .clock ? 440 : 600)
            let occupied = approvalCrowded ? [CGRect(x: 0, y: 768, width: 1200, height: 32)] : scoreRegression ? [CGRect(x: 0, y: 740, width: 510, height: 60),
                CGRect(x: 960, y: 740, width: 240, height: 60)]
                : name == "notch-menu-crowded" ? [CGRect(x: 0, y: 768, width: 500, height: 32)] : []
            let placement = MenuBarPlacement.layout(base: geometry, screen: screen, occupied: occupied,
                expanded: activity != nil, satelliteCount: 2)
            presentation.secondaryFits = placement.secondary != nil; presentation.tertiaryFits = placement.tertiary != nil
            presentation.secondaryOnLeft = (placement.secondary?.midX ?? 0) < 600
            presentation.tertiaryOnLeft = (placement.tertiary?.midX ?? 1200) < 600
            let primary = placement.primary, secondary = placement.secondary ?? geometry.secondary, tertiary = placement.tertiary ?? geometry.tertiary
            presentation.expandedPanelHeight = activity != nil ? geometry.primary.height : 520
            if activity != nil { presentation.expandedPanelWidth = geometry.primary.width }
            if name == "notch-merged" || name == "notch-score-merged" { presentation.mergeActivities() }
            let canvasHeight = activity == nil ? 100.0 : geometry.primary.height + 60
            let view = ZStack(alignment: .topLeading) {
                Color(red: 0.12, green: 0.14, blue: 0.19)
                Text("SYNTHETIC PREVIEW · ACTUAL APP VIEWS").font(.system(size: 12)).foregroundColor(.white.opacity(0.25))
                    .padding(.top, canvasHeight - 30).padding(.leading, 28)
                NotchContentView( dataManager: data, nowPlayingManager: media,
                    clockManager: clock, calendarManager: calendar, approvals: ApprovalManager.visualFixture(github: name == "notch-chatgpt-approval"), presentation: presentation)
                    .frame(width: primary.width, height: primary.height)
                    .position(x: primary.midX, y: screen.maxY - primary.midY)
                if presentation.showsSecondary { SecondaryActivityView(dataManager: data, media: media, clock: clock, calendar: calendar, approvals: ApprovalManager.visualFixture(github: name == "notch-chatgpt-approval"),
                    presentation: presentation, third: false)
                    .frame(width: secondary.width, height: secondary.height)
                    .position(x: secondary.midX, y: screen.maxY - secondary.midY) }
                if presentation.showsTertiary { SecondaryActivityView(dataManager: data, media: media, clock: clock, calendar: calendar, approvals: ApprovalManager.visualFixture(github: name == "notch-chatgpt-approval"),
                    presentation: presentation, third: true)
                    .frame(width: tertiary.width, height: tertiary.height)
                    .position(x: tertiary.midX, y: screen.maxY - tertiary.midY) }
                RoundedRectangle(cornerRadius: 8).fill(Color.black)
                    .overlay(Circle().fill(Color(red: 0.04, green: 0.06, blue: 0.09)).frame(width: 6, height: 6))
                    .frame(width: 180, height: 32).position(x: 600, y: 16)
            }.frame(width: 1200, height: canvasHeight)
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(x: 0, y: 0, width: 1200, height: canvasHeight)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name + ".png"))
        }
        let setup = NSHostingView(rootView: IslandSetupView(clock: NativeClockManager(defaults: defaults),
            calendar: CalendarManager(defaults: defaults), media: media, approvals: ApprovalManager(), presentation: IslandPresentation(defaults: defaults), done: {}).background(Color(nsColor: .windowBackgroundColor)))
        setup.frame = NSRect(x: 0, y: 0, width: 490, height: 600)
        let setupWindow = NSWindow(contentRect: setup.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        setupWindow.contentView = setup
        setup.needsLayout = true
        setup.layoutSubtreeIfNeeded()
        setupWindow.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let setupBitmap = setup.bitmapImageRepForCachingDisplay(in: setup.bounds)!
        setup.cacheDisplay(in: setup.bounds, to: setupBitmap)
        try setupBitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("setup.png"))
        print("Rendered actual island views with synthetic three-activity fixtures; no live integrations started.")
    }
}
