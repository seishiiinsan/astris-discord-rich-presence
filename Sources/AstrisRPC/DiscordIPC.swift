import Foundation

/// Minimal client for Discord's local IPC socket (discord-ipc-N).
/// Not thread-safe: use from a single serial queue.
final class DiscordIPC {
    private enum Opcode: UInt32 { case handshake = 0, frame = 1, close = 2 }

    let clientID: String
    private var fd: Int32 = -1

    var isConnected: Bool { fd >= 0 }

    init(clientID: String) {
        self.clientID = clientID
    }

    deinit { disconnect() }

    func connect() -> Bool {
        if isConnected { return true }
        for path in Self.socketPaths() where openSocket(path) {
            if handshake() { return true }
            disconnect()
        }
        return false
    }

    func disconnect() {
        if fd >= 0 { close(fd) }
        fd = -1
    }

    /// Sets the activity, or clears it when `activity` is nil.
    func setActivity(_ activity: [String: Any]?) -> Bool {
        var args: [String: Any] = ["pid": Int(getpid())]
        if let activity { args["activity"] = activity }
        let payload: [String: Any] = [
            "cmd": "SET_ACTIVITY",
            "args": args,
            "nonce": UUID().uuidString,
        ]
        guard send(.frame, payload), let (op, _) = readFrame(), op == Opcode.frame.rawValue else {
            disconnect()
            return false
        }
        return true
    }

    // MARK: - Socket

    private static func socketPaths() -> [String] {
        let env = ProcessInfo.processInfo.environment
        var bases = [env["TMPDIR"], env["XDG_RUNTIME_DIR"], NSTemporaryDirectory(), "/tmp"]
            .compactMap { $0 }
            .map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 }
        var seen = Set<String>()
        bases = bases.filter { seen.insert($0).inserted }
        return bases.flatMap { base in (0..<10).map { "\(base)/discord-ipc-\($0)" } }
    }

    private func openSocket(_ path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }

        var on: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else {
            close(sock)
            return false
        }
        withUnsafeMutableBytes(of: &addr.sun_path) { $0.copyBytes(from: bytes) }
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            close(sock)
            return false
        }
        fd = sock
        return true
    }

    private func handshake() -> Bool {
        guard send(.handshake, ["v": 1, "client_id": clientID]),
              let (op, body) = readFrame(), op == Opcode.frame.rawValue,
              (body["evt"] as? String) == "READY"
        else { return false }
        return true
    }

    // MARK: - Framing (u32 LE opcode, u32 LE length, JSON)

    private func send(_ op: Opcode, _ object: [String: Any]) -> Bool {
        guard isConnected, let payload = try? JSONSerialization.data(withJSONObject: object) else { return false }
        var frame = Data()
        withUnsafeBytes(of: op.rawValue.littleEndian) { frame.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(payload.count).littleEndian) { frame.append(contentsOf: $0) }
        frame.append(payload)

        return frame.withUnsafeBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return false }
            var sent = 0
            while sent < raw.count {
                let n = write(fd, base + sent, raw.count - sent)
                if n <= 0 { return false }
                sent += n
            }
            return true
        }
    }

    private func readFrame() -> (UInt32, [String: Any])? {
        guard let header = readExact(8) else { return nil }
        let op = header.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self)) }
        let len = header.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self)) }
        guard len < 1 << 20, let body = readExact(Int(len)) else { return nil }
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
        return (op, json)
    }

    private func readExact(_ count: Int) -> Data? {
        var data = Data(count: count)
        var got = 0
        let ok = data.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return count == 0 }
            while got < count {
                let n = read(fd, base + got, count - got)
                if n <= 0 { return false }
                got += n
            }
            return true
        }
        return ok ? data : nil
    }
}
