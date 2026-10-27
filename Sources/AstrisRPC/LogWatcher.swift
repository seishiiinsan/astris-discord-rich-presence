import Foundation

/// Tails Astris' (Ryujinx-based) log files to know which game is running.
final class LogWatcher {
    struct Game: Equatable {
        let name: String
        let titleID: String
        let start: Date
    }

    private(set) var game: Game?
    private(set) var currentLog: URL?

    /// User-chosen log folder; overrides auto-detection.
    var customDirectory: URL?

    private var offset: UInt64 = 0
    private var remainder = ""
    private var logStart = Date()

    // "Application Loaded: The Legend of Zelda v1.2.0 [0100F2C0115B6000] [64-bit]"
    private let loadedRegex = try! NSRegularExpression(
        pattern: #"Application Loaded: (.+?)(?: v\S+)? \[([0-9A-Fa-f]{16})\]"#)
    // Leading elapsed time of each Ryujinx log line: "00:01:23.456 |I| ..."
    private let elapsedRegex = try! NSRegularExpression(pattern: #"^(\d+):(\d{2}):(\d{2})\.(\d+)"#)
    private let stopRegex = try! NSRegularExpression(
        pattern: #"Emulation stopped|Stopping emulation|Application Unloaded|Emulation was stopped|AppHost.*(?:Exit|Dispos)"#,
        options: [.caseInsensitive])

    func reset() {
        game = nil
        currentLog = nil
        offset = 0
        remainder = ""
    }

    func poll() {
        guard let latest = latestLogFile() else {
            reset()
            return
        }
        if latest != currentLog {
            reset()
            currentLog = latest
            let attrs = try? FileManager.default.attributesOfItem(atPath: latest.path)
            logStart = (attrs?[.creationDate] as? Date) ?? Date()
        }
        readNewLines(from: latest)
    }

    // MARK: - Reading

    private func readNewLines(from url: URL) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        if size < offset {
            // File was truncated or replaced.
            offset = 0
            remainder = ""
            game = nil
        }
        guard size > offset else { return }

        try? handle.seek(toOffset: offset)
        guard let data = try? handle.readToEnd() else { return }
        offset += UInt64(data.count)

        let text = remainder + String(decoding: data, as: UTF8.self)
        var lines = text.components(separatedBy: "\n")
        remainder = lines.removeLast()
        lines.forEach(parse)
    }

    private func parse(_ line: String) {
        let range = NSRange(line.startIndex..., in: line)
        if let m = loadedRegex.firstMatch(in: line, range: range),
           let nameRange = Range(m.range(at: 1), in: line),
           let idRange = Range(m.range(at: 2), in: line) {
            game = Game(
                name: String(line[nameRange]).trimmingCharacters(in: .whitespaces),
                titleID: line[idRange].uppercased(),
                start: timestamp(of: line, range: range))
        } else if stopRegex.firstMatch(in: line, range: range) != nil {
            game = nil
        }
    }

    private func timestamp(of line: String, range: NSRange) -> Date {
        guard let m = elapsedRegex.firstMatch(in: line, range: range) else { return Date() }
        func part(_ i: Int) -> Double { Range(m.range(at: i), in: line).flatMap { Double(line[$0]) } ?? 0 }
        let elapsed = part(1) * 3600 + part(2) * 60 + part(3)
        return min(logStart.addingTimeInterval(elapsed), Date())
    }

    // MARK: - Discovery

    private func latestLogFile() -> URL? {
        let fm = FileManager.default
        var best: (URL, Date)?
        for dir in logDirectories() {
            let files = (try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for file in files where file.pathExtension.lowercased() == "log" {
                let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                if best == nil || date > best!.1 { best = (file, date) }
            }
        }
        return best?.0
    }

    func logDirectories() -> [URL] {
        if let customDirectory { return [customDirectory] }

        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let appSupport = home.appendingPathComponent("Library/Application Support")
        var roots = [appSupport, home.appendingPathComponent("Library/Logs")]

        // Sandboxed builds keep their data inside their container.
        let containers = home.appendingPathComponent("Library/Containers")
        for c in (try? fm.contentsOfDirectory(at: containers, includingPropertiesForKeys: nil)) ?? []
        where Self.isEmulatorName(c.lastPathComponent) {
            roots.append(c.appendingPathComponent("Data/Library/Application Support"))
            roots.append(c.appendingPathComponent("Data/Library/Logs"))
        }

        var dirs: [URL] = []
        for root in roots {
            for child in (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            where Self.isEmulatorName(child.lastPathComponent) {
                dirs.append(child)
                for sub in (try? fm.contentsOfDirectory(at: child, includingPropertiesForKeys: nil)) ?? [] {
                    let name = sub.lastPathComponent.lowercased()
                    if name == "logs" || name == "log" || Self.isEmulatorName(name) {
                        dirs.append(sub)
                        dirs.append(sub.appendingPathComponent("Logs"))
                    }
                }
            }
        }
        return dirs
    }

    private static func isEmulatorName(_ name: String) -> Bool {
        let n = name.lowercased()
        return (n.contains("astris") && !n.contains("astrisrpc")) || n.contains("ryujinx")
    }
}
