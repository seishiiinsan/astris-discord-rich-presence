import Carbon
import Foundation

/// System-wide shortcuts (Carbon hot keys: no Accessibility permission needed).
/// ⌃⌥⌘D shows or hides the presence, ⌃⌥⌘H hides the current game on Discord.
final class HotKeys {
    enum Action: UInt32 {
        case toggleDiscord = 1
        case toggleHideGame = 2

        var keyCode: Int {
            switch self {
            case .toggleDiscord: return kVK_ANSI_D
            case .toggleHideGame: return kVK_ANSI_H
            }
        }
    }

    static let modifiers = UInt32(controlKey | optionKey | cmdKey)
    /// For menus: same keys, same modifiers.
    static func keyEquivalent(_ action: Action) -> String {
        action == .toggleDiscord ? "d" : "h"
    }

    var onAction: ((Action) -> Void)?
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    var isRegistered: Bool { handler != nil }

    func register() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let got = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard got == noErr, let action = HotKeys.Action(rawValue: id.id) else { return OSStatus(eventNotHandledErr) }
            Unmanaged<HotKeys>.fromOpaque(userData).takeUnretainedValue().onAction?(action)
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else {
            Log.shared.add("Hot keys: handler failed (\(status))")
            return
        }
        for action in [Action.toggleDiscord, .toggleHideGame] {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x4152_5043), id: action.rawValue) // 'ARPC'
            let result = RegisterEventHotKey(UInt32(action.keyCode), Self.modifiers, id, GetApplicationEventTarget(), 0, &ref)
            if result == noErr, let ref {
                refs.append(ref)
            } else {
                // Usually: another app already owns this shortcut.
                Log.shared.add("Hot key \(action) unavailable (\(result))")
            }
        }
    }

    func unregister() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }

    deinit { unregister() }
}
