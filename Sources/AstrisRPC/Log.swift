import Foundation

/// Recent events, kept in memory for the diagnostic and optionally written to
/// ~/Library/Logs/AstrisRPC.log (Settings → General).
final class Log {
    static let shared = Log()
    static let limit = 300

    static let file: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/AstrisRPC.log")

    private let lock = NSLock()
    private var lines: [String] = []
    private let queue = DispatchQueue(label: "astris-rpc.log")
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    var toFile = false

    func add(_ message: String, at date: Date = Date()) {
        lock.lock()
        let line = "\(formatter.string(from: date))  \(message)"
        if lines.last?.hasSuffix("  \(message)") == true {
            lock.unlock()
            return
        }
        lines.append(line)
        if lines.count > Self.limit { lines.removeFirst(lines.count - Self.limit) }
        let write = toFile
        lock.unlock()
        guard write else { return }
        queue.async { Self.append(line + "\n") }
    }

    var recent: [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }

    private static func append(_ text: String) {
        let data = Data(text.utf8)
        // Start over past 1 MB.
        let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        if size > 1_000_000 { try? FileManager.default.removeItem(at: file) }
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: file)
        }
    }
}
