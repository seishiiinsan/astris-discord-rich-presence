import Foundation

/// ROM files found in the user's games folder.
enum GameLibrary {
    struct Game: Identifiable, Hashable {
        var id: String { url.path }
        let url: URL
        let name: String
        let titleID: String?
    }

    /// Scans `folder` (and up to 2 levels of subfolders). TitleIDs come from the file
    /// name, from games already seen running (`known`, keyed by ROM file name), or from
    /// a title match (`titles`, normalized title → TitleID).
    static func scan(_ folder: URL, known: [String: String] = [:], titles: [String: String] = [:]) -> [Game] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey],
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
                    ?? titles[GameDetector.normalize(name)]))
        }
        return games.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
