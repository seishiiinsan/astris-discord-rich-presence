import Foundation

/// French or English: the choice from Settings, else the system's first language.
enum L10n {
    enum Language: String, CaseIterable {
        case system, french, english
    }

    static let languageKey = "language"

    static var isFrench = resolve(
        Language(rawValue: UserDefaults.standard.string(forKey: languageKey) ?? "") ?? .system,
        preferred: Locale.preferredLanguages)

    static func resolve(_ language: Language, preferred: [String]) -> Bool {
        switch language {
        case .french: return true
        case .english: return false
        case .system: return preferred.first?.lowercased().hasPrefix("fr") ?? false
        }
    }

    static func tr(_ french: String, _ english: String) -> String {
        isFrench ? french : english
    }
}
