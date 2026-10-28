import Foundation

/// Play sessions recorded by Astris RPC, for the Stats tab.
/// Saved in ~/Library/Application Support/AstrisRPC/history.json. Use from the main queue.
final class PlayHistory: ObservableObject {
    struct Session: Codable, Equatable {
        let name: String
        let titleID: String?
        /// ROM file name, like per-game settings.
        let rom: String
        let start: Date
        var end: Date

        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    struct GameTotal: Identifiable, Equatable {
        var id: String { rom }
        let rom: String
        let name: String
        let titleID: String?
        let total: TimeInterval
        let recent: TimeInterval
        let lastPlayed: Date
    }

    static let limit = 2000
    /// A longer gap between two polls (sleep, idle, Astris closed) starts a new session.
    static let maxGap: TimeInterval = 60
    private static let saveInterval: TimeInterval = 60

    @Published private(set) var sessions: [Session]
    private let file: URL?
    private var open = false
    private var lastSave = Date.distantPast

    init(file: URL? = AppPaths.support?.appendingPathComponent("history.json")) {
        self.file = file
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        sessions = file.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? decoder.decode([Session].self, from: $0) } ?? []
    }

    /// Called at each poll with the game being played (nil: none, or idle).
    func update(name: String?, titleID: String?, romPath: String?, now: Date = Date()) {
        guard let name, let romPath else {
            if open { open = false; save() }
            return
        }
        let rom = (romPath as NSString).lastPathComponent
        if open, let last = sessions.last, last.rom == rom, now.timeIntervalSince(last.end) <= Self.maxGap {
            sessions[sessions.count - 1].end = now
            if now.timeIntervalSince(lastSave) >= Self.saveInterval { save() }
            return
        }
        sessions.append(Session(name: name, titleID: titleID, rom: rom, start: now, end: now))
        if sessions.count > Self.limit { sessions.removeFirst(sessions.count - Self.limit) }
        open = true
        save()
    }

    func save() {
        lastSave = Date()
        guard let file else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(sessions) { try? data.write(to: file, options: .atomic) }
    }

    func clear() {
        sessions = []
        open = false
        save()
    }

    /// Time played since `date` (sessions cut at that date).
    func total(since date: Date) -> TimeInterval {
        sessions.reduce(0) { $0 + Self.overlap($1, since: date) }
    }

    /// One row per game, most played first. `recent` counts time since `date`.
    func totals(recentSince date: Date) -> [GameTotal] {
        Dictionary(grouping: sessions, by: \.rom).map { rom, list in
            let latest = list.max { $0.end < $1.end }!
            return GameTotal(
                rom: rom, name: latest.name, titleID: list.lazy.compactMap(\.titleID).first,
                total: list.reduce(0) { $0 + $1.duration },
                recent: list.reduce(0) { $0 + Self.overlap($1, since: date) },
                lastPlayed: latest.end)
        }
        .sorted { ($0.total, $0.lastPlayed) > ($1.total, $1.lastPlayed) }
    }

    private static func overlap(_ s: Session, since date: Date) -> TimeInterval {
        max(0, s.end.timeIntervalSince(max(s.start, date)))
    }

    static func startOfWeek(_ now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    }

    /// "0 min", "45 min", "3 h 05"
    static func format(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) min" }
        return String(format: "%d h %02d", minutes / 60, minutes % 60)
    }
}
