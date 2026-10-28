import CoreGraphics
import Foundation
import GameController

/// How long since the player last touched the keyboard, the mouse or a game controller.
/// Controllers count because Switch games are mostly played with one.
final class IdleMonitor {
    private var lastControllerInput = Date()

    init() {
        // Without this, controller events only reach the frontmost app.
        GCController.shouldMonitorBackgroundEvents = true
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            self?.watch(controller)
        }
        GCController.controllers().forEach(watch)
    }

    private func watch(_ controller: GCController) {
        controller.handlerQueue = .main
        controller.physicalInputProfile.valueDidChangeHandler = { [weak self] _, _ in
            self?.lastControllerInput = Date()
        }
    }

    /// Seconds without any input. Call from the main queue.
    var idleTime: TimeInterval {
        // kCGAnyInputEventType (~0) isn't imported as a case.
        let anyInput = CGEventType(rawValue: UInt32.max) ?? .mouseMoved
        let system = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInput)
        return min(system, Date().timeIntervalSince(lastControllerInput))
    }

    static func isIdle(idleTime: TimeInterval, afterMinutes minutes: Int) -> Bool {
        minutes > 0 && idleTime >= TimeInterval(minutes * 60)
    }
}
