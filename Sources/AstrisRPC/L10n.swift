import Foundation

/// French when the system's first language is French, English otherwise.
enum L10n {
    static var isFrench = Locale.preferredLanguages.first?.lowercased().hasPrefix("fr") ?? false

    static func tr(_ french: String, _ english: String) -> String {
        isFrench ? french : english
    }
}
