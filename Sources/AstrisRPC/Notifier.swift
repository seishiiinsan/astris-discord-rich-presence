import Foundation
import UserNotifications

/// macOS notifications: Discord lost, update available, weekly summary.
final class Notifier {
    private static let summaryKey = "lastWeeklySummary"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Only inside the .app: the notification center needs a bundle (not the case under `swift test`).
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { Log.shared.add("Notifications: \(error.localizedDescription)") }
            else if !granted { Log.shared.add("Notifications not allowed") }
        }
    }

    func send(id: String, title: String, body: String) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    // MARK: - Weekly summary

    /// Sunday from 19:00, once per week.
    func isSummaryDue(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.weekday, .hour], from: now)
        guard parts.weekday == 1, (parts.hour ?? 0) >= 19 else { return false }
        let week = PlayHistory.startOfWeek(now, calendar: calendar)
        let last = defaults.object(forKey: Self.summaryKey) as? Date
        return last.map { $0 < week } ?? true
    }

    func markSummarySent(now: Date = Date(), calendar: Calendar = .current) {
        defaults.set(PlayHistory.startOfWeek(now, calendar: calendar), forKey: Self.summaryKey)
    }

    /// "8 h 20 cette semaine, surtout Zelda (5 h 10)." — nil without play time.
    static func weeklySummary(_ rows: [PlayHistory.GameTotal], name: (PlayHistory.GameTotal) -> String) -> String? {
        let played = rows.filter { $0.recent >= 60 }.sorted { $0.recent > $1.recent }
        guard let top = played.first else { return nil }
        let total = PlayHistory.format(played.reduce(0) { $0 + $1.recent })
        if played.count == 1 {
            return L10n.tr("\(total) cette semaine, sur \(name(top)).", "\(total) this week, on \(name(top)).")
        }
        return L10n.tr(
            "\(total) cette semaine sur \(played.count) jeux, surtout \(name(top)) (\(PlayHistory.format(top.recent))).",
            "\(total) this week across \(played.count) games, mostly \(name(top)) (\(PlayHistory.format(top.recent))).")
    }
}
