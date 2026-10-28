import Foundation

/// What Astris (Ryujinx) keeps in its Config.json: game folders, docked mode, multiplayer.
struct AstrisConfig: Equatable {
    var gameDirectories: [URL] = []
    /// nil when the setting is missing.
    var docked: Bool?
    /// Local wireless (LDN) emulation is on.
    var multiplayer = false

    static var files: [URL] {
        GameDetector.astrisGamesDirectories.flatMap { games in
            let base = games.deletingLastPathComponent()
            return ["Config.json", "config.json"].map { base.appendingPathComponent($0) }
        }
    }

    /// First readable Config.json.
    static func load() -> AstrisConfig? {
        for file in files {
            if let data = try? Data(contentsOf: file), let config = parse(data) { return config }
        }
        return nil
    }

    static func parse(_ data: Data) -> AstrisConfig? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var config = AstrisConfig()
        config.gameDirectories = (json["game_dirs"] as? [String] ?? [])
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
        config.docked = json["docked_mode"] as? Bool
        // An enum, written as a name ("Disabled", "LdnMitm"…) or a number depending on the version.
        switch json["multiplayer_mode"] {
        case let name as String: config.multiplayer = !name.isEmpty && name.lowercased() != "disabled"
        case let n as NSNumber: config.multiplayer = n.intValue != 0
        default: break
        }
        return config
    }

    /// Folders that exist, for the games folder suggestion.
    var existingGameDirectories: [URL] {
        gameDirectories.filter { FileManager.default.fileExists(atPath: $0.path) }
    }
}
