import Foundation
import Darwin
import IslandCore

// Silence is intentional: unavailable, malformed, disconnected or expired requests return
// to the agent's normal approval flow. Never default to allow or execute tool_input.
func run() {
    let args = CommandLine.arguments
    guard args.count == 3, args[1] == "--notch-approval", let provider = ApprovalProvider(rawValue: args[2]),
          let endpoint = ApprovalSocket.privateFile(ApprovalSocket.directory.appendingPathComponent("endpoint.json")),
          let config = try? JSONSerialization.jsonObject(with: endpoint) as? [String: String],
          let secret = config["token"], let path = config["socket"], var address = ApprovalSocket.address(path) else { return }
    guard let input = ApprovalSocket.readLine(STDIN_FILENO, timeout: 2, maximum: ApprovalRequest.maximumBytes),
          let hook = try? JSONSerialization.jsonObject(with: input) as? [String: Any] else { return }
    let id = UUID()
    guard let packet = try? JSONSerialization.data(withJSONObject: ["version": 1, "id": id.uuidString,
        "provider": provider.rawValue, "token": secret, "created": Date().timeIntervalSince1970, "hook": hook]),
        ApprovalRequest.decode(packet, secret: secret) != nil else { return }
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return }; defer { close(fd) }
    ApprovalSocket.protect(fd)
    var sendTimeout = timeval(tv_sec: 2, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &sendTimeout, socklen_t(MemoryLayout<timeval>.size))
    let connected = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    guard connected == 0, ApprovalSocket.sameUser(fd), ApprovalSocket.send(packet, to: fd),
          let response = ApprovalSocket.readLine(fd, timeout: 120, maximum: 4096),
          let output = ApprovalRequest.hookOutput(response, expectedID: id) else { return }
    FileHandle.standardOutput.write(output + Data([10]))
}
run()
