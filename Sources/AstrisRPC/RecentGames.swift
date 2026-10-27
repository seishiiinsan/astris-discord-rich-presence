import Foundation

/// Games seen running in Astris, newest first, persisted in UserDefaults.
final class RecentGames {
    struct Entry: Codable, Equatable {
        let name: String
        let titleID: String?
        let romPath: String
        var lastPlayed: Date
    }

    static let limit = 5
    private static let key = "recentGames"

    private let defaults: UserDefaults
    private(set) var entries: [Entry]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
    }

    func record(name: String, titleID: String?, romPath: String, at date: Date = Date()) {
        entries.removeAll { $0.romPath == romPath }
        entries.insert(Entry(name: name, titleID: titleID, romPath: romPath, lastPlayed: date), at: 0)
        entries = Array(entries.prefix(Self.limit))
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
