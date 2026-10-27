import Foundation
import Darwin
import IslandCore

/// All descriptors/state belong to this utility queue. Idle listeners use no polling.
final class ApprovalServer {
    var onRequest: ((ApprovalRequest) -> Void)?
    var onRemoval: ((UUID) -> Void)?
    var onError: ((String) -> Void)?
    private let directory: URL
    init(directory: URL = ApprovalSocket.directory) { self.directory = directory }
    private let queue = DispatchQueue(label: "com.notchislandsports.approvals", qos: .userInitiated)
    private var listener: DispatchSourceRead?
    private var lockFD: Int32 = -1
    private var socketFolder: String?
    private var secret = ""
    private var peers: [Int32: Peer] = [:]
    private var recent: [UUID: Date] = [:]
    private final class Peer {
        let source: DispatchSourceRead
        var buffer = Data()
        var request: ApprovalRequest?
        var timeout: DispatchWorkItem?
        init(_ source: DispatchSourceRead) { self.source = source }
    }
    func start() { queue.async { [weak self] in self?.listen() } }
    func stop() { queue.async { [weak self] in self?.shutdown() } }
    func decide(_ id: UUID, _ decision: ApprovalDecision, completion: ((Bool) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self, let pair = self.peers.first(where: { $0.value.request?.id == id }),
                  let request = pair.value.request else { completion?(false); return }
            let actual = request.expires > Date() ? decision : .passthrough
            let sent = self.finish(pair.key, decision: actual)
            completion?(sent && actual == decision)
        }
    }
    private func listen() {
        guard listener == nil else { return }
        do {
            try ApprovalSocket.ensurePrivateDirectory(directory)
            lockFD = open(directory.appendingPathComponent("listener.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { throw CocoaError(.fileLocking) }
            var template = Array("/tmp/nis-approval-\(geteuid()).XXXXXX".utf8CString)
            guard let folder = mkdtemp(&template) else { throw CocoaError(.fileWriteUnknown) }
            socketFolder = String(cString: folder)
            let path = socketFolder! + "/socket"
            guard var address = ApprovalSocket.address(path) else { throw CocoaError(.fileWriteInvalidFileName) }
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
            ApprovalSocket.protect(fd)
            let bound = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
            }
            guard bound == 0, Darwin.listen(fd, 8) == 0 else { let code = errno; close(fd); throw NSError(domain: NSPOSIXErrorDomain, code: Int(code)) }
            _ = chmod(path, 0o600); _ = fcntl(fd, F_SETFL, O_NONBLOCK)
            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
            source.setEventHandler { [weak self] in self?.acceptConnections(fd) }
            source.setCancelHandler { close(fd) }
            listener = source; source.resume()
            secret = UUID().uuidString + UUID().uuidString
            let locator = try JSONSerialization.data(withJSONObject: ["socket": path, "token": secret])
            let endpoint = directory.appendingPathComponent("endpoint.json")
            try locator.write(to: endpoint, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: endpoint.path)
        } catch { shutdown(); onError?("Approval connection could not start (\((error as NSError).domain):\((error as NSError).code)). Quit other copies and reconnect in setup.") }
    }
    private func acceptConnections(_ listener: Int32) {
        for _ in 0..<16 {
            let fd = accept(listener, nil, nil)
            guard fd >= 0 else { return }
            guard peers.count < 8, ApprovalSocket.sameUser(fd) else { close(fd); continue }
            ApprovalSocket.protect(fd); _ = fcntl(fd, F_SETFL, O_NONBLOCK)
            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
            let peer = Peer(source); peers[fd] = peer
            source.setEventHandler { [weak self] in self?.read(fd) }
            source.setCancelHandler { close(fd) }
            source.resume()
            let timeout = DispatchWorkItem { [weak self, weak peer] in
                guard let self, let peer, self.peers[fd] === peer else { return }
                self.finish(fd, decision: .passthrough)
            }
            peer.timeout = timeout; queue.asyncAfter(deadline: .now() + 2, execute: timeout)
        }
    }
    private func read(_ fd: Int32) {
        guard let peer = peers[fd] else { return }
        var bytes = [UInt8](repeating: 0, count: 8192)
        let count = Darwin.read(fd, &bytes, bytes.count)
        if count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK) { return }
        guard count > 0, peer.request == nil else { finish(fd, decision: .passthrough); return }
        peer.buffer.append(contentsOf: bytes.prefix(count))
        guard peer.buffer.count <= ApprovalRequest.maximumBytes else { finish(fd, decision: .passthrough); return }
        guard let end = peer.buffer.firstIndex(of: 10) else { return }
        let data = Data(peer.buffer[..<end]); peer.buffer.removeAll()
        recent = recent.filter { $0.value > Date() }
        guard let request = ApprovalRequest.decode(data, secret: secret), recent[request.id] == nil, recent.count < 256 else {
            finish(fd, decision: .passthrough); return
        }
        recent[request.id] = request.expires
        peer.request = request; peer.timeout?.cancel()
        let timeout = DispatchWorkItem { [weak self, weak peer] in
            guard let self, let peer, self.peers[fd] === peer else { return }
            self.finish(fd, decision: .passthrough)
        }
        peer.timeout = timeout
        queue.asyncAfter(deadline: .now() + max(0, request.expires.timeIntervalSinceNow), execute: timeout)
        onRequest?(request)
    }
    @discardableResult private func finish(_ fd: Int32, decision: ApprovalDecision) -> Bool {
        guard let peer = peers.removeValue(forKey: fd) else { return false }
        var sent = false
        peer.timeout?.cancel()
        if let request = peer.request {
            // Tiny nonblocking response; a failed/disconnected write never implies approval.
            sent = ApprovalSocket.send(ApprovalRequest.response(id: request.id, decision: decision), to: fd)
            onRemoval?(request.id)
        }
        peer.source.cancel()
        return sent
    }
    private func shutdown() {
        for fd in Array(peers.keys) { finish(fd, decision: .passthrough) }
        listener?.cancel(); listener = nil
        if !secret.isEmpty {
            let endpoint = directory.appendingPathComponent("endpoint.json")
            if let data = ApprovalSocket.privateFile(endpoint),
               let value = try? JSONSerialization.jsonObject(with: data) as? [String: String], value["token"] == secret {
                try? FileManager.default.removeItem(at: endpoint)
            }
        }
        secret = ""; recent.removeAll()
        if let socketFolder { try? FileManager.default.removeItem(atPath: socketFolder) }; socketFolder = nil
        if lockFD >= 0 { close(lockFD); lockFD = -1 }
    }
}
