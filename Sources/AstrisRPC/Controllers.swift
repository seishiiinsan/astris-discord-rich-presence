import Foundation
import GameController

/// Connected game controllers and their battery, for the menu and the low-battery alert.
enum Controllers {
    struct Info: Equatable {
        let name: String
        /// 0…1, nil when the controller doesn't report it.
        let battery: Float?
        let charging: Bool
    }

    static let lowBattery: Float = 0.2

    static func current() -> [Info] {
        GCController.controllers().map { c in
            let battery = c.battery
            let level = battery.flatMap { $0.batteryState == .unknown && $0.batteryLevel <= 0 ? nil : $0.batteryLevel }
            return Info(
                name: c.vendorName ?? L10n.tr("Manette", "Controller"),
                battery: level,
                charging: battery?.batteryState == .charging || battery?.batteryState == .full)
        }
    }

    /// "Pro Controller · 80 %", "DualSense · 15 % ⚡︎"
    static func label(_ info: Info) -> String {
        guard let level = info.battery else { return info.name }
        return "\(info.name) · \(Int((level * 100).rounded())) %" + (info.charging ? " ⚡︎" : "")
    }

    static func isLow(_ info: Info) -> Bool {
        guard let level = info.battery else { return false }
        return !info.charging && level <= lowBattery
    }
}
