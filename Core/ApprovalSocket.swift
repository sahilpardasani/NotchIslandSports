import Foundation
import Darwin

/// Owner-only local IPC. No TCP listener, shell input, or executable request content.
public enum ApprovalSocket {
    public static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/NotchIslandSports/Approvals", isDirectory: true)
    }
    public static func ensurePrivateDirectory(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var info = stat()
        guard lstat(directory.path, &info) == 0, info.st_uid == geteuid(), info.st_mode & S_IFMT == S_IFDIR,
              info.st_mode & 0o077 == 0 else { throw CocoaError(.fileWriteNoPermission) }
    }
    public static func address(_ path: String) -> sockaddr_un? {
        var value = sockaddr_un(); value.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8) + [0]
        guard bytes.count <= MemoryLayout.size(ofValue: value.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &value.sun_path) { $0.copyBytes(from: bytes + Array(repeating: 0, count: $0.count - bytes.count)) }
        value.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        return value
    }
    public static func sameUser(_ fd: Int32) -> Bool {
        var uid: uid_t = 0, gid: gid_t = 0
        return getpeereid(fd, &uid, &gid) == 0 && uid == geteuid()
    }
    public static func protect(_ fd: Int32) {
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
    }
    public static func send(_ data: Data, to fd: Int32) -> Bool {
        let packet = data + Data([10])
        return packet.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let sent = Darwin.send(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset, 0)
                if sent <= 0 { return false }; offset += sent
            }
            return true
        }
    }
    public static func readLine(_ fd: Int32, timeout: Double, maximum: Int) -> Data? {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var result = Data(), bytes = [UInt8](repeating: 0, count: 4096)
        while ProcessInfo.processInfo.systemUptime < deadline {
            var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let remaining = max(1, Int32((deadline - ProcessInfo.processInfo.systemUptime) * 1000))
            guard poll(&descriptor, 1, remaining) > 0 else { return nil }
            let count = read(fd, &bytes, bytes.count)
            if count == 0 { return result.isEmpty ? nil : result }
            guard count > 0 else { return nil }
            result.append(contentsOf: bytes.prefix(count))
            guard result.count <= maximum else { return nil }
            if let end = result.firstIndex(of: 10) { return Data(result[..<end]) }
        }
        return nil
    }
    /// stdin carries one JSON object, not necessarily a newline-delimited record.
    public static func readJSONObject(_ fd: Int32, timeout: Double, maximum: Int) -> Data? {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var result = Data(), bytes = [UInt8](repeating: 0, count: 8192)
        while ProcessInfo.processInfo.systemUptime < deadline {
            var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let remaining = max(1, Int32((deadline - ProcessInfo.processInfo.systemUptime) * 1000))
            let ready = poll(&descriptor, 1, remaining)
            if ready < 0 && errno == EINTR { continue }
            guard ready > 0 else { return nil }
            let count = read(fd, &bytes, bytes.count)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { return nil }
            result.append(contentsOf: bytes.prefix(count))
            guard result.count <= maximum else { return nil }
            if (try? JSONSerialization.jsonObject(with: result)) is [String: Any] { return result }
        }
        return nil
    }

    public static func privateFile(_ url: URL, maximum: Int = 4096) -> Data? {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { return nil }; defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == geteuid(), info.st_mode & S_IFMT == S_IFREG,
              info.st_mode & 0o077 == 0, info.st_size <= maximum else { return nil }
        var bytes = [UInt8](repeating: 0, count: maximum + 1)
        let count = read(fd, &bytes, bytes.count)
        return count >= 0 && count <= maximum ? Data(bytes.prefix(count)) : nil
    }
}
