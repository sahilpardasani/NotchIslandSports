import Foundation
import Combine
import SwiftUI
import Cocoa

// MARK: - NowPlayingTrack Struct

struct NowPlayingTrack: Equatable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let elapsedTime: TimeInterval
    let isPlaying: Bool
    let artwork: Data?
    let dominantColor: Color
}

// MARK: - NowPlayingManager

@MainActor
final class NowPlayingManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var currentTrack: NowPlayingTrack?
    @Published var showMediaMode: Bool = false
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var mediaRemoteBundle: CFBundle?
    private var getNowPlayingInfoFunc: (@convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void)?
    
    // MARK: - Init
    
    init() {
        loadMediaRemote()
        startPolling()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Framework Loading
    
    private func loadMediaRemote() {
        let bundlePath = "/System/Library/PrivateFrameworks/MediaRemote.framework"
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: bundlePath)) else {
            return
        }
        
        self.mediaRemoteBundle = bundle
        
        if let getInfoPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            typealias MRGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
            self.getNowPlayingInfoFunc = unsafeBitCast(getInfoPointer, to: MRGetNowPlayingInfoFunction.self)
        }
    }
    
    // MARK: - Polling
    
    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateNowPlayingInfo()
            }
        }
        // Run immediately
        updateNowPlayingInfo()
    }
    
    func updateNowPlayingInfo() {
        guard let getNowPlayingInfo = getNowPlayingInfoFunc else { return }
        
        getNowPlayingInfo(DispatchQueue.main) { [weak self] info in
            guard let self = self else { return }
            
            guard let info = info,
                  let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String,
                  !title.isEmpty else {
                self.currentTrack = nil
                return
            }
            
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "Unknown Artist"
            let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
            let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? TimeInterval ?? 0.0
            let elapsedTime = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval ?? 0.0
            
            // Playback rate: 0.0 = paused, 1.0 = playing
            let playbackRate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0.0
            let isPlaying = playbackRate > 0.0
            
            let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
            
            // Extract dominant color if artwork changed or use fallback
            let dominantColor: Color
            if let artwork = artworkData {
                dominantColor = self.extractDominantColor(from: artwork) ?? Color(hex: "A855F7") // Premium purple fallback
            } else {
                dominantColor = Color(hex: "A855F7")
            }
            
            let newTrack = NowPlayingTrack(
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                elapsedTime: elapsedTime,
                isPlaying: isPlaying,
                artwork: artworkData,
                dominantColor: dominantColor
            )
            
            if self.currentTrack != newTrack {
                self.currentTrack = newTrack
                
                // Automatically switch to media mode if music starts playing and we weren't in media mode
                if isPlaying && !self.showMediaMode {
                    self.showMediaMode = true
                }
            }
        }
    }
    
    // MARK: - Dominant Color Extraction
    
    private func extractDominantColor(from data: Data) -> Color? {
        guard let nsImage = NSImage(data: data) else { return nil }
        
        let size = NSSize(width: 1, height: 1)
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 4,
            bitsPerPixel: 32
        ) else { return nil }
        
        representation.size = size
        
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context
        
        nsImage.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: nsImage.size),
            operation: .copy,
            fraction: 1.0
        )
        
        NSGraphicsContext.restoreGraphicsState()
        
        if let nsColor = representation.colorAt(x: 0, y: 0) {
            // Boost saturation & brightness to make sure color looks dynamic and vibrant on dark notch background
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            
            nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            
            // Adjust saturation/brightness to avoid muddy colors
            let adjustedSaturation = max(saturation, 0.6) // Ensure rich saturation
            let adjustedBrightness = max(brightness, 0.7) // Ensure bright visible lines
            
            let vibrantColor = NSColor(
                calibratedHue: hue,
                saturation: adjustedSaturation,
                brightness: adjustedBrightness,
                alpha: alpha
            )
            return Color(vibrantColor)
        }
        return nil
    }
    
    // MARK: - Playback Controls
    
    func playPause() {
        executeAppleScript("""
        tell application "System Events"
            key code 16
        end tell
        """)
        // Trigger quick local update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateNowPlayingInfo()
        }
    }
    
    func nextTrack() {
        executeAppleScript("""
        tell application "System Events"
            key code 19
        end tell
        """)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateNowPlayingInfo()
        }
    }
    
    func previousTrack() {
        executeAppleScript("""
        tell application "System Events"
            key code 20
        end tell
        """)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateNowPlayingInfo()
        }
    }
    
    func skipForward15() {
        executeAppleScript("""
        -- Try Safari first
        try
            tell application "Safari"
                repeat with w in windows
                    repeat with t in tabs of w
                        try
                            set tabUrl to URL of t
                            set tabName to name of t
                            if tabUrl contains "youtube.com" or tabUrl contains "video" or tabUrl contains "netflix" or tabUrl contains "primevideo" or tabName contains "YouTube" then
                                tell t to do JavaScript "document.querySelector('video').currentTime += 15;"
                            end if
                        end try
                    end repeat
                end repeat
            end tell
        end try

        -- Try Chrome
        try
            tell application "Google Chrome"
                repeat with w in windows
                    repeat with t in tabs of w
                        try
                            set tabUrl to URL of t
                            set tabName to name of t
                            if tabUrl contains "youtube.com" or tabUrl contains "video" or tabUrl contains "netflix" or tabUrl contains "primevideo" or tabName contains "YouTube" then
                                execute t javascript "document.querySelector('video').currentTime += 15;"
                            end if
                        end try
                    end repeat
                end repeat
            end tell
        end try

        -- Try Spotify
        try
            tell application "Spotify"
                if player state is playing or player state is paused then
                    set player position to (player position + 15)
                end if
            end tell
        end try

        -- Try Music
        try
            tell application "Music"
                if player state is playing or player state is paused then
                    set player position to (player position + 15)
                end if
            end tell
        end try
        """)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.updateNowPlayingInfo()
        }
    }
    
    func skipBackward15() {
        executeAppleScript("""
        -- Try Safari first
        try
            tell application "Safari"
                repeat with w in windows
                    repeat with t in tabs of w
                        try
                            set tabUrl to URL of t
                            set tabName to name of t
                            if tabUrl contains "youtube.com" or tabUrl contains "video" or tabUrl contains "netflix" or tabUrl contains "primevideo" or tabName contains "YouTube" then
                                tell t to do JavaScript "document.querySelector('video').currentTime -= 15;"
                            end if
                        end try
                    end repeat
                end repeat
            end tell
        end try

        -- Try Chrome
        try
            tell application "Google Chrome"
                repeat with w in windows
                    repeat with t in tabs of w
                        try
                            set tabUrl to URL of t
                            set tabName to name of t
                            if tabUrl contains "youtube.com" or tabUrl contains "video" or tabUrl contains "netflix" or tabUrl contains "primevideo" or tabName contains "YouTube" then
                                execute t javascript "document.querySelector('video').currentTime -= 15;"
                            end if
                        end try
                    end repeat
                end repeat
            end tell
        end try

        -- Try Spotify
        try
            tell application "Spotify"
                if player state is playing or player state is paused then
                    set player position to (player position - 15)
                end if
            end tell
        end try

        -- Try Music
        try
            tell application "Music"
                if player state is playing or player state is paused then
                    set player position to (player position - 15)
                end if
            end tell
        end try
        """)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.updateNowPlayingInfo()
        }
    }
    
    private func executeAppleScript(_ scriptText: String) {
        guard let script = NSAppleScript(source: scriptText) else { return }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
    }
}
