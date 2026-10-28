import Foundation

/// Astris' screenshots and saves, plus Astris RPC's own backups.
enum AstrisFiles {
    /// ~/Library/Application Support/Astris (and the sandboxed variant).
    static var baseDirectories: [URL] {
        GameDetector.astrisGamesDirectories.map { $0.deletingLastPathComponent() }
    }

    static var screenshotDirectories: [URL] {
        let pictures = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures")
        return baseDirectories.map { $0.appendingPathComponent("screenshots") }
            + [pictures.appendingPathComponent("Astris")]
    }

    static var saveDirectory: URL? {
        baseDirectories.map { $0.appendingPathComponent("bis/user/save") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// ~/Documents/Astris RPC/Sauvegardes
    static var backupDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Astris RPC")
            .appendingPathComponent(L10n.tr("Sauvegardes", "Backups"))
    }

    static let keptBackups = 20
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic"]

    // MARK: - Screenshots

    /// Newest image in `directories`.
    static func latestScreenshot(in directories: [URL] = screenshotDirectories) -> (url: URL, date: Date)? {
        var best: (url: URL, date: Date)?
        for dir in directories {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)) ?? []
            for file in files where imageExtensions.contains(file.pathExtension.lowercased()) {
                let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                if date > (best?.date ?? .distantPast) { best = (file, date) }
            }
        }
        return best
    }

    // MARK: - Save backups

    static func backupName(at date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return "Astris saves \(f.string(from: date)).zip"
    }

    /// Newest first.
    static func backups(in directory: URL = backupDirectory) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "zip" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    /// Zips the save folder; keeps the newest `keptBackups`. Blocking: call off the main queue.
    @discardableResult
    static func backUpSaves(from saves: URL? = saveDirectory, to directory: URL = backupDirectory, at date: Date = Date()) throws -> URL {
        guard let saves else { throw CocoaError(.fileNoSuchFile) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let archive = directory.appendingPathComponent(backupName(at: date))
        try run("/usr/bin/ditto", ["-c", "-k", "--keepParent", saves.path, archive.path])
        for old in backups(in: directory).dropFirst(keptBackups) { try? FileManager.default.removeItem(at: old) }
        return archive
    }

    /// Puts an archive back; the current saves are kept next to it as "save before restore …".
    static func restore(_ archive: URL, into saves: URL) throws {
        let fm = FileManager.default
        let parent = saves.deletingLastPathComponent()
        let work = fm.temporaryDirectory.appendingPathComponent("AstrisRPC-restore-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        try run("/usr/bin/ditto", ["-x", "-k", archive.path, work.path])
        guard let restored = try fm.contentsOfDirectory(at: work, includingPropertiesForKeys: [.isDirectoryKey]).first(where: {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }) else { throw CocoaError(.fileReadCorruptFile) }
        if fm.fileExists(atPath: saves.path) {
            let aside = parent.appendingPathComponent("save before restore \(backupName().dropLast(4))")
            try fm.moveItem(at: saves, to: aside)
        }
        try fm.moveItem(at: restored, to: saves)
    }

    private static func run(_ tool: String, _ args: [String]) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: tool)
        task.arguments = args
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
    }
}
