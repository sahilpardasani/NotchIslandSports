import Foundation
import IslandCore

/// One event-driven helper while awake; no browser tab scanning or media-key synthesis.
@MainActor
final class SystemMediaAdapter {
    var onSnapshot: ((MediaSnapshot?) -> Void)?
    var onFailure: (() -> Void)?
    private var process: Process?
    private var output: Pipe?
    private var command: Process?
    private var generation = 0
    private let io = DispatchQueue(label: "com.notchislandsports.media-stream", qos: .utility)
    private var resources: (String, String)? {
        guard let base = Bundle.main.resourceURL else { return nil }
        let script = base.appendingPathComponent("mediaremote-adapter.pl").path
        let framework = Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks/MediaRemoteAdapter.framework").path
        guard FileManager.default.fileExists(atPath: script),
              FileManager.default.fileExists(atPath: framework + "/MediaRemoteAdapter") else { return nil }
        return (script, framework)
    }
    var available: Bool { resources != nil }
    var listening: Bool { process?.isRunning == true }

    func start() {
        guard process == nil, let (script, framework) = resources else { return }
        generation += 1
        let token = generation
        let child = Process(), pipe = Pipe()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        child.arguments = [script, framework, "stream", "--no-diff", "--micros", "--debounce=50", "--allow-missing-title"]
        child.standardOutput = pipe; child.standardError = FileHandle.nullDevice
        process = child; output = pipe
        child.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.process = nil; self.output = nil
                self.onSnapshot?(nil); self.onFailure?()
            }
        }
        do { try child.run() }
        catch { process = nil; output = nil; onFailure?(); return }
        // Blocking pipe reads happen only on this utility queue, never the main thread.
        io.async { [weak self] in
            var pending = Data()
            while true {
                let chunk = pipe.fileHandleForReading.availableData
                if chunk.isEmpty { break }
                pending.append(chunk)
                if pending.count > 8_000_000 { child.terminate(); break }
                while let end = pending.firstIndex(of: 10) {
                    let line = Data(pending[..<end]); pending.removeSubrange(...end)
                    let snapshot = MediaSnapshot.decode(line)
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token else { return }
                        self.onSnapshot?(snapshot)
                    }
                }
            }
            try? pipe.fileHandleForReading.close()
        }
    }
    func stop() {
        generation += 1
        process?.terminate(); process = nil; output = nil
        command?.terminate(); command = nil
    }
    func send(_ id: Int, expected: NowPlayingTrack, completion: @escaping (Bool) -> Void) {
        runControl(["send", String(id)], expected: expected, completion: completion)
    }
    func seek(to position: Double, expected: NowPlayingTrack, completion: @escaping (Bool) -> Void) {
        guard position.isFinite, position >= 0, position <= Double(Int64.max / 1_000_000) else { completion(false); return }
        runControl(["seek", String(Int64(position * 1_000_000))], expected: expected, completion: completion)
    }
    private func runControl(_ arguments: [String], expected: NowPlayingTrack, completion: @escaping (Bool) -> Void) {
        guard command == nil, expected.hasSourceTitle, let bundle = expected.sourceBundleID, let (script, framework) = resources else { completion(false); return }
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        child.arguments = [script, framework] + arguments
        var environment = ProcessInfo.processInfo.environment
        environment["NOTCH_EXPECTED_MEDIA_BUNDLE"] = bundle
        environment["NOTCH_EXPECTED_MEDIA_TITLE"] = expected.title
        child.environment = environment
        child.standardOutput = FileHandle.nullDevice; child.standardError = FileHandle.nullDevice
        let token = generation
        child.terminationHandler = { [weak self] child in
            Task { @MainActor in
                guard let self, self.generation == token, self.command === child else { return }
                self.command = nil
                completion(child.terminationStatus == 0)
            }
        }
        command = child
        do { try child.run() } catch { command = nil; completion(false); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak child] in
            if child?.isRunning == true { child?.terminate() }
        }
    }
}
