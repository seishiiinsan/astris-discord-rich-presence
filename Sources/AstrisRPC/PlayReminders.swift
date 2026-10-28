import Foundation

/// When to remind a break, celebrate a play-time milestone or a session record.
enum PlayReminders {
    /// Hours on one game worth a notification.
    static let milestones = [10, 25, 50, 100, 200, 500]
    static let breakChoices = [0, 60, 90, 120, 180]

    /// Every `minutes` of uninterrupted play.
    static func isBreakDue(sessionStart: Date?, now: Date, everyMinutes minutes: Int, lastReminder: Date?) -> Bool {
        guard let sessionStart, minutes > 0 else { return false }
        let interval = TimeInterval(minutes * 60)
        guard now.timeIntervalSince(sessionStart) >= interval else { return false }
        guard let lastReminder, lastReminder >= sessionStart else { return true }
        return now.timeIntervalSince(lastReminder) >= interval
    }

    /// The milestone (in hours) passed between two total play times, if any.
    static func crossedMilestone(from before: TimeInterval, to after: TimeInterval) -> Int? {
        milestones.last { TimeInterval($0 * 3600) > before && TimeInterval($0 * 3600) <= after }
    }

    /// The current session just beat the longest one (30 min at least, so the first days stay quiet).
    static func beatsRecord(current: TimeInterval, previousCurrent: TimeInterval, record: TimeInterval) -> Bool {
        record >= 1800 && previousCurrent <= record && current > record
    }
}
