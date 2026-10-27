import Foundation
import Combine
import SwiftUI
import Cocoa
import IslandCore

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
    var sourceBundleID: String? = nil
    var hasSourceTitle = true
}

// MARK: - NowPlayingManager

@MainActor
final class NowPlayingManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var currentTrack: NowPlayingTrack?
    @Published var showMediaMode: Bool = false
    @Published private(set) var controlError: String?
    @Published private(set) var isActive = false
    private(set) var positionAnchor = PlaybackAnchor(position: 0, instant: 0, rate: 0, duration: 0)
    @Published var enabled = UserDefaults.standard.object(forKey: "ExperimentalMediaEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "ExperimentalMediaEnabled")
            if enabled && isActive { updateNowPlayingInfo() }
            else {
                adapter.stop(); adapterRetry?.cancel(); adapterRetry = nil
                timer?.invalidate(); timeout?.cancel(); requestID = nil; clearSession()
                commandProcess?.terminate(); commandProcess = nil
            }
        }
    }
    var canControl: Bool {
        guard currentTrack?.hasSourceTitle == true, let id = currentTrack?.sourceBundleID else { return false }
        return adapter.listening || NativeMediaPlayer(rawValue: id) != nil
    }
    func elapsedTime() -> TimeInterval { positionAnchor.value(at: ProcessInfo.processInfo.systemUptime) }
    private var getPID: (@convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void)?
    private var requestID: UUID?
    private var timeout: DispatchWorkItem?
    private(set) var artworkImage: NSImage?
    private var lastArtwork: Data?
    private var lastColor = Color(hex: "A855F7")
    private var commandProcess: Process?
    
    // MARK: - Private Properties
    
    private var sessionPresence = MediaSessionPresence()
    private var terminationObserver: NSObjectProtocol?
    private let adapter = SystemMediaAdapter()
    private var adapterRetry: DispatchWorkItem?
    private var adapterFailures = 0
    private var timer: Timer?
    private var lowPower = false
    private var mediaRemoteBundle: CFBundle?
    private var getNowPlayingInfoFunc: (@convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void)?
    
    // MARK: - Init
    
    init() {
        loadMediaRemote()
        adapter.onSnapshot = { [weak self] snapshot in self?.accept(snapshot) }
        adapter.onFailure = { [weak self] in
            guard let self, self.isActive, self.enabled else { return }
            self.clearSession()
            self.controlError = "Media connection unavailable. Retrying automatically."
            self.adapterRetry?.cancel()
            self.adapterFailures += 1
            let retry = DispatchWorkItem { [weak self] in self?.updateNowPlayingInfo() }
            self.adapterRetry = retry
            DispatchQueue.main.asyncAfter(deadline: .now() + EnergyPolicy.mediaRetry(failures: self.adapterFailures), execute: retry)
        }
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
        loadSourceLookup(bundle)
        
        if let getInfoPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            typealias MRGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
            self.getNowPlayingInfoFunc = unsafeBitCast(getInfoPointer, to: MRGetNowPlayingInfoFunction.self)
        }
    }
    
    // Both metadata and source identification use private MediaRemote APIs.
    // Unsupported systems degrade to an empty state, never synthetic metadata.
    private func loadSourceLookup(_ bundle: CFBundle) {
        if let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationPID" as CFString) {
            typealias Lookup = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
            getPID = unsafeBitCast(pointer, to: Lookup.self)
        }
    }

    // MARK: - Polling
    
    func startPolling() {
        guard !isActive else { return }
        isActive = true
        adapterFailures = 0
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                Task { @MainActor in
                    guard let self, let bundle = app?.bundleIdentifier,
                          bundle == self.currentTrack?.sourceBundleID else { return }
                    self.clearSession()
                }
            }
        updateNowPlayingInfo()
    }

    func stopPolling() {
        isActive = false
        if let terminationObserver { NSWorkspace.shared.notificationCenter.removeObserver(terminationObserver) }
        terminationObserver = nil
        adapter.stop(); adapterRetry?.cancel(); adapterRetry = nil
        clearSession()
        timer?.invalidate(); timer = nil
        timeout?.cancel(); timeout = nil
        requestID = nil
        commandProcess?.terminate(); commandProcess = nil
    }

    func setLowPower(_ value: Bool) {
        guard lowPower != value else { return }
        lowPower = value
        if !adapter.available && requestID == nil { scheduleNext() }
    }

    private func scheduleNext() {
        guard isActive, enabled else { return }
        timer?.invalidate()
        let base: TimeInterval = currentTrack == nil ? 30 : (currentTrack?.isPlaying == true ? 5 : 15)
        let interval = base * (lowPower ? 2 : 1)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.updateNowPlayingInfo() }
        }
        timer?.tolerance = interval * 0.2
    }

    func updateNowPlayingInfo() {
        guard isActive, enabled, requestID == nil else { return }
        if adapter.available {
            adapterRetry?.cancel(); adapterRetry = nil
            adapter.start()
            return
        }
        guard let getInfo = getNowPlayingInfoFunc else { return }
        let token = UUID()
        requestID = token
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.requestID == token else { return }
            self.requestID = nil
            self.clearSession()
            self.scheduleNext()
        }
        self.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: timeout)
        let fetch: (Int32) -> Void = { [weak self] pid in
            getInfo(DispatchQueue.main) { [weak self] info in
                guard let self, self.requestID == token else { return }
                self.timeout?.cancel()
                self.requestID = nil
                defer { self.scheduleNext() }
                guard self.isActive, self.enabled, let info,
                      let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String, !title.isEmpty else {
                    self.clearSession(); return
                }
                let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
                let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
                let position = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
                let artwork = (info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data).flatMap { $0.count <= 4_000_000 ? $0 : nil }
                if artwork != self.lastArtwork {
                    self.lastArtwork = artwork
                    self.artworkImage = artwork.flatMap(NSImage.init(data:))
                    self.lastColor = self.artworkImage.flatMap { self.extractDominantColor(from: $0) } ?? Color(hex: "A855F7")
                }
                let anchor = PlaybackAnchor(position: position,
                    instant: ProcessInfo.processInfo.systemUptime, rate: rate, duration: duration)
                let track = NowPlayingTrack(title: title,
                    artist: info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "Unknown Artist",
                    album: info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "",
                    duration: duration, elapsedTime: position, isPlaying: rate > 0,
                    artwork: artwork, dominantColor: self.lastColor,
                    sourceBundleID: pid > 0 ? NSRunningApplication(processIdentifier: pid)?.bundleIdentifier : nil)
                guard self.sessionPresence.update(bundleID: track.sourceBundleID, title: track.title, playing: track.isPlaying) else {
                    self.clearSession(); return
                }
                self.publish(track, anchor: anchor)
            }
        }
        if let getPID { getPID(DispatchQueue.main, fetch) } else { fetch(0) }
    }

    private func accept(_ snapshot: MediaSnapshot?) {
        guard isActive, enabled else { return }
        guard let snapshot,
              !NSRunningApplication.runningApplications(withBundleIdentifier: snapshot.bundleID).isEmpty,
              sessionPresence.update(bundleID: snapshot.bundleID, title: snapshot.title, playing: snapshot.playing)
        else { clearSession(); return }
        adapterFailures = 0
        if controlError != nil { controlError = nil }
        if snapshot.artwork != lastArtwork {
            lastArtwork = snapshot.artwork
            artworkImage = snapshot.artwork.flatMap(NSImage.init(data:))
            lastColor = artworkImage.flatMap { extractDominantColor(from: $0) } ?? Color(hex: "A855F7")
        }
        let position = snapshot.position(now: Date().timeIntervalSince1970)
        let anchor = PlaybackAnchor(position: position, instant: ProcessInfo.processInfo.systemUptime,
            rate: snapshot.rate, duration: snapshot.duration)
        let track = NowPlayingTrack(title: snapshot.title, artist: snapshot.artist, album: snapshot.album,
            duration: snapshot.duration, elapsedTime: position, isPlaying: snapshot.playing,
            artwork: snapshot.artwork, dominantColor: lastColor, sourceBundleID: snapshot.bundleID,
            hasSourceTitle: snapshot.hasSourceTitle)
        publish(track, anchor: anchor)
    }

    private func publish(_ track: NowPlayingTrack, anchor: PlaybackAnchor) {
        let correction = EnergyPolicy.positionChanged(previous: positionAnchor, next: anchor,
                                                       now: ProcessInfo.processInfo.systemUptime)
        // Compare presentation metadata independently of advancing elapsed time.
        let metadataChanged = currentTrack.map {
            $0.title != track.title || $0.artist != track.artist || $0.album != track.album ||
            $0.duration != track.duration || $0.isPlaying != track.isPlaying ||
            $0.sourceBundleID != track.sourceBundleID || $0.hasSourceTitle != track.hasSourceTitle || $0.artwork != track.artwork
        } ?? true
        positionAnchor = anchor
        if metadataChanged || correction { currentTrack = track }
    }

    private func clearSession() {
        sessionPresence.clear()
        if currentTrack != nil { currentTrack = nil }
        artworkImage = nil; lastArtwork = nil
        positionAnchor = PlaybackAnchor(position: 0, instant: 0, rate: 0, duration: 0)
    }

    // MARK: - Dominant Color Extraction
    
    private func extractDominantColor(from nsImage: NSImage) -> Color? {
        
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
    // Fixed scripts target one identified application. No global key events or tab sweeps.
    func playPause() { send(.playPause) }
    func nextTrack() { send(.next) }
    func previousTrack() { send(.previous) }
    func skipForward15() { send(.forward) }
    func skipBackward15() { send(.backward) }

    private typealias Command = NativeMediaPlayer.Command
    private func send(_ command: Command) {
        if adapter.listening, isActive, enabled, let track = currentTrack {
            let id: Int
            switch command {
            case .playPause: id = 2
            case .next: id = 4
            case .previous: id = 5
            case .forward: id = 13
            case .backward: id = 12
            }
            adapter.send(id, expected: track) { [weak self] success in
                guard let self, self.isActive, self.enabled,
                      self.currentTrack?.sourceBundleID == track.sourceBundleID,
                      self.currentTrack?.title == track.title else { return }
                if success { self.controlError = nil }
                else if NativeMediaPlayer(rawValue: track.sourceBundleID ?? "") != nil {
                    self.sendNative(command, expected: track)
                } else { self.controlError = "The media player changed or rejected this control. Try again." }
            }
            return
        }
        guard let track = currentTrack else { return }
        sendNative(command, expected: track)
    }

    private func sendNative(_ command: Command, expected track: NowPlayingTrack) {
        guard isActive, enabled, commandProcess == nil, let source = track.sourceBundleID,
              let player = NativeMediaPlayer(rawValue: source), let getPID else { return }
        getPID(DispatchQueue.main) { [weak self] pid in
            guard let self, self.isActive, self.enabled, self.currentTrack?.sourceBundleID == source,
                  self.currentTrack?.title == track.title,
                  NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == source,
                  self.commandProcess == nil else { return }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", player.script(for: command)]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { [weak self] process in
                Task { @MainActor in
                    guard let self, self.commandProcess === process else { return }
                    self.commandProcess = nil
                    self.controlError = process.terminationStatus == 0 ? nil : "Playback control failed. Check Automation permission for this player."
                    self.updateNowPlayingInfo()
                }
            }
            self.commandProcess = process
            do { try process.run() }
            catch { self.commandProcess = nil; self.controlError = "Unable to control this player" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak process] in
                if process?.isRunning == true { process?.terminate() }
            }
        }
    }
}

#if DEBUG
extension NowPlayingManager {
    func setArtworkFixture(_ image: NSImage?) { artworkImage = image }

    /// Exercises real publication logic without starting a media process or source query.
    func applyEnergyFixture(_ track: NowPlayingTrack, anchor: PlaybackAnchor) {
        publish(track, anchor: anchor)
    }
}
#endif
