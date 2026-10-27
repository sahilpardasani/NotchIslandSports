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
        media.currentTrack = NowPlayingTrack(title: "Preview track", artist: "Synthetic fixture", album: "", duration: 180,
            elapsedTime: 30, isPlaying: true, artwork: nil, dominantColor: .purple)
        let suite = "NotchRender." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, activity) in [("notch-three-activities", Optional<IslandActivity>.none),
                                  ("notch-calendar-expanded", .calendar), ("notch-clock-expanded", .clock),
                                  ("notch-clock-paused", .clock), ("notch-clock-unavailable", .clock),
                                  ("notch-clock-multiple", .clock), ("notch-clock-empty", .clock),
                                  ("notch-sports-expanded", .sports), ("notch-merged", nil)] {
            let clock = NativeClockManager.visualFixture(paused: name == "notch-clock-paused",
                controllable: name != "notch-clock-unavailable", count: name == "notch-clock-multiple" ? 3 : name == "notch-clock-empty" ? 0 : 1,
                remaining: name == "notch-clock-multiple" ? 3723 : 197)
            let presentation = IslandPresentation(defaults: defaults)
            presentation.cameraHeight = 32
            presentation.update(sports: true, music: true, clock: true, calendar: true)
            if let activity { presentation.open(activity) }
            let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
            let geometry = NotchGeometry.layout(screen: screen, safeTop: 32, leftArea: nil, rightArea: nil,
                expanded: activity != nil,
                contentHeight: activity == .calendar ? 420 : activity == .clock ? NativeClockView.contentHeight(timerCount: clock.timers.count) : 360,
                expandedWidth: activity == .clock ? 440 : 600)
            presentation.expandedPanelHeight = activity != nil ? geometry.primary.height : 520
            if name == "notch-merged" { presentation.mergeActivities() }
            let canvasHeight = activity == nil ? 100.0 : geometry.primary.height + 60
            let view = ZStack(alignment: .topLeading) {
                Color(red: 0.12, green: 0.14, blue: 0.19)
                Text("SYNTHETIC PREVIEW · ACTUAL APP VIEWS").font(.system(size: 12)).foregroundColor(.white.opacity(0.25))
                    .padding(.top, canvasHeight - 30).padding(.leading, 28)
                NotchContentView(hoverState: HoverState(), dataManager: data, nowPlayingManager: media,
                    clockManager: clock, calendarManager: calendar, presentation: presentation)
                    .frame(width: geometry.primary.width, height: geometry.primary.height)
                    .position(x: geometry.primary.midX, y: screen.maxY - geometry.primary.midY)
                if presentation.showsSecondary { SecondaryActivityView(dataManager: data, media: media, clock: clock, calendar: calendar,
                    presentation: presentation, third: false)
                    .frame(width: geometry.secondary.width, height: geometry.secondary.height)
                    .position(x: geometry.secondary.midX, y: screen.maxY - geometry.secondary.midY) }
                if presentation.showsTertiary { SecondaryActivityView(dataManager: data, media: media, clock: clock, calendar: calendar,
                    presentation: presentation, third: true)
                    .frame(width: geometry.tertiary.width, height: geometry.tertiary.height)
                    .position(x: geometry.tertiary.midX, y: screen.maxY - geometry.tertiary.midY) }
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
        print("Rendered actual island views with synthetic three-activity fixtures; no live integrations started.")
    }
}
