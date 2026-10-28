import Foundation

/// ROM files found in the user's games folder.
enum GameLibrary {
    struct Game: Identifiable, Hashable {
        var id: String { url.path }
        let url: URL
        let name: String
        let titleID: String?
        /// Bytes on disk.
        var size: Int64 = 0
    }

    /// Files that look like the same game twice: same base-game TitleID (updates and DLC aside), or same name.
    static func duplicates(_ games: [Game]) -> Set<Game.ID> {
        let keyed = games.compactMap { game -> (String, Game.ID)? in
            if let id = game.titleID {
                guard GameDetector.kind(of: id) == .base else { return nil }
                return ("id:" + id, game.id)
            }
            return ("name:" + GameDetector.normalize(game.name), game.id)
        }
        let groups = Dictionary(grouping: keyed, by: \.0)
        return Set(groups.values.filter { $0.count > 1 }.flatMap { $0.map(\.1) })
    }

    static func formatSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Scans `folder` (and up to 2 levels of subfolders). TitleIDs come from the file
    /// name, from games already seen running (`known`, keyed by ROM file name), or from
    /// a title match (`titles`, normalized title → TitleID).
    static func scan(_ folder: URL, known: [String: String] = [:], titles: [String: String] = [:]) -> [Game] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else { return [] }

        var games: [Game] = []
        for case let url as URL in walker {
            if walker.level > 3 { walker.skipDescendants() }
            guard GameDetector.isROM(url.path) else { continue }
            let file = url.deletingPathExtension().lastPathComponent
            let name = GameDetector.cleanName(file)
            games.append(Game(
                url: url,
                name: name,
                titleID: GameDetector.titleID(in: file)?.uppercased()
                    ?? known[url.lastPathComponent]
                    ?? titles[GameDetector.normalize(name)],
                size: Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)))
        }
        return games.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
