import Foundation

/// User-editable presence lines: "{game}", "Sur Astris · {played} jouées"…
/// A " · " segment whose token has no value is dropped, so "{played}" never shows up empty.
enum PresenceTemplate {
    static let tokens = ["game", "played", "version", "mode", "multi", "status"]

    static let defaultDetails = "{game}"
    static var defaultState: String { L10n.tr("Sur Astris · {played} jouées · {multi}", "On Astris · {played} played · {multi}") }

    static func render(_ template: String, values: [String: String?]) -> String? {
        var kept: [String] = []
        for part in template.components(separatedBy: " · ") {
            var text = part
            var missing = false
            for (key, value) in values where text.contains("{\(key)}") {
                if let value, !value.isEmpty {
                    text = text.replacingOccurrences(of: "{\(key)}", with: value)
                } else {
                    missing = true
                }
            }
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if !missing && !trimmed.isEmpty { kept.append(trimmed) }
        }
        return kept.isEmpty ? nil : kept.joined(separator: " · ")
    }
}
