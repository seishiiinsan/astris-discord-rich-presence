import Foundation

/// Finds the game Astris is running: the ROM it keeps open (via lsof)
/// and the `games/<TitleID>/gui/metadata.json` it touches at launch.
final class GameDetector {
    struct Game: Equatable {
        let name: String
        let titleID: String?
        let start: Date
        /// Total time played before this session, from Astris' metadata.
        let playedTime: TimeInterval?
    }

    private static let romExtensions: Set<String> = ["xci", "xcz", "nsp", "nsz", "nro"]
    private static let titleIDRegex = try! NSRegularExpression(pattern: #"\[?(01[0-9A-Fa-f]{14})\]?"#)

    private(set) var game: Game?
    private var romPath: String?

    func reset() {
        game = nil
        romPath = nil
    }

    func poll(pid: pid_t) {
        guard let rom = openROM(pid: pid) else {
            reset()
            return
        }
        guard rom != romPath else { return }
        romPath = rom
        game = makeGame(rom: rom)
    }

    // MARK: - ROM

    private func openROM(pid: pid_t) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-n", "-P", "-p", String(pid), "-Fn"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .lazy
            .filter { $0.hasPrefix("n/") }
            .map { String($0.dropFirst()) }
            .first { Self.romExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
    }

    private func makeGame(rom: String) -> Game {
        let fileName = ((rom as NSString).lastPathComponent as NSString).deletingPathExtension
        var titleID = Self.titleID(in: fileName)
        var metadata: [String: Any]?
        var metadataDate: Date?

        if let entry = titleID.flatMap(metadataEntry(for:)) ?? latestMetadataEntry() {
            titleID = titleID ?? entry.titleID
            metadata = entry.json
            metadataDate = entry.date
        }

        let title = (metadata?["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let start = (metadata?["last_played_utc"] as? String).flatMap(Self.parseDate)
            ?? metadataDate ?? Date()
        return Game(
            name: title ?? Self.cleanName(fileName),
            titleID: titleID?.uppercased(),
            start: min(start, Date()),
            playedTime: Self.parsePlayed(metadata?["timespan_played"] ?? metadata?["time_played"]))
    }

    // MARK: - Metadata

    private struct MetadataEntry {
        let titleID: String
        let date: Date
        let json: [String: Any]
    }

    private var gamesDirectories: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            "Library/Application Support/Astris/games",
            "Library/Containers/V380-Ori.Astris/Data/Library/Application Support/Astris/games",
        ].map { home.appendingPathComponent($0) }
    }

    private func metadataEntry(for titleID: String) -> MetadataEntry? {
        for dir in gamesDirectories {
            let file = dir.appendingPathComponent("\(titleID.lowercased())/gui/metadata.json")
            if let entry = readMetadata(file, titleID: titleID) { return entry }
        }
        return nil
    }

    /// Astris rewrites the running game's metadata.json at launch.
    private func latestMetadataEntry() -> MetadataEntry? {
        let fm = FileManager.default
        var best: MetadataEntry?
        for dir in gamesDirectories {
            for game in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
                let file = game.appendingPathComponent("gui/metadata.json")
                if let entry = readMetadata(file, titleID: game.lastPathComponent),
                   entry.date > (best?.date ?? .distantPast) {
                    best = entry
                }
            }
        }
        return best
    }

    private func readMetadata(_ file: URL, titleID: String) -> MetadataEntry? {
        guard let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        else { return nil }
        let json = (try? Data(contentsOf: file))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        return MetadataEntry(titleID: titleID, date: date, json: json)
    }

    // MARK: - Helpers

    private static func titleID(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let m = titleIDRegex.firstMatch(in: text, range: range),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    /// "Super_Mario [0100...][v0] (EU)" -> "Super Mario"
    private static func cleanName(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: #"\[[^\]]*\]|\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? name : cleaned
    }

    /// .NET TimeSpan "[d.]hh:mm:ss[.fffffff]", or plain seconds.
    private static func parsePlayed(_ value: Any?) -> TimeInterval? {
        if let n = value as? NSNumber { return n.doubleValue }
        guard let string = value as? String else { return nil }
        let parts = string.split(separator: ":")
        guard parts.count == 3 else { return Double(string) }
        let head = parts[0].split(separator: ".")
        let days = head.count == 2 ? Double(head[0]) ?? 0 : 0
        let hours = Double(head.last ?? "0") ?? 0
        let minutes = Double(parts[1]) ?? 0
        let seconds = Double(parts[2]) ?? 0
        return days * 86400 + hours * 3600 + minutes * 60 + seconds
    }

    /// Ryujinx writes e.g. "2026-10-27T10:44:12.1234567Z"; keep second precision.
    private static func parseDate(_ string: String) -> Date? {
        guard string.count >= 19 else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: String(string.prefix(19)) + "Z")
    }
}
