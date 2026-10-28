import Foundation

/// User preferences shared by the menu, the presence and the Settings window.
/// Per-game settings are keyed by ROM file name, so they survive moving the games folder.
final class GameSettings: ObservableObject {
    struct GamePrefs: Codable, Equatable {
        var hidden = false
        var customName: String?
    }

    static let shared = GameSettings()

    private static let showKey = "presenceEnabled"
    private static let folderKey = "gamesFolder"
    private static let prefsKey = "gamePrefs"
    private static let titleIDsKey = "knownTitleIDs"
    private static let logKey = "writeLog"
    private static let idleKey = "idleMinutes"

    static let idleChoices = [0, 5, 10, 15, 30]

    private static let detailsKey = "detailsTemplate"
    private static let stateKey = "stateTemplate"
    private static let eShopButtonKey = "eShopButton"
    private static let buttonLabelKey = "customButtonLabel"
    private static let buttonURLKey = "customButtonURL"

    private let defaults: UserDefaults

    @Published var showOnDiscord: Bool {
        didSet { defaults.set(showOnDiscord, forKey: Self.showKey) }
    }

    /// Also write the event log to ~/Library/Logs/AstrisRPC.log.
    @Published var writeLog: Bool {
        didSet {
            defaults.set(writeLog, forKey: Self.logKey)
            Log.shared.toFile = writeLog
        }
    }

    /// Show "Idle" on Discord after this many minutes without input (0: never).
    @Published var idleMinutes: Int {
        didSet { defaults.set(idleMinutes, forKey: Self.idleKey) }
    }

    /// Presence lines (nil: defaults, see `PresenceTemplate`).
    @Published var detailsTemplate: String? {
        didSet { Self.store(detailsTemplate, Self.detailsKey, in: defaults) }
    }

    @Published var stateTemplate: String? {
        didSet { Self.store(stateTemplate, Self.stateKey, in: defaults) }
    }

    @Published var showEShopButton: Bool {
        didSet { defaults.set(showEShopButton, forKey: Self.eShopButtonKey) }
    }

    /// Replaces the "Astris" button when both are set.
    @Published var customButtonLabel: String? {
        didSet { Self.store(customButtonLabel, Self.buttonLabelKey, in: defaults) }
    }

    @Published var customButtonURL: String? {
        didSet { Self.store(customButtonURL, Self.buttonURLKey, in: defaults) }
    }

    var customButton: (label: String, url: String)? {
        guard let label = customButtonLabel, let url = customButtonURL, Presence.isWebURL(url, max: 512) else { return nil }
        return (label, url)
    }

    private static func store(_ value: String?, _ key: String, in defaults: UserDefaults) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty { defaults.set(trimmed, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    @Published var gamesFolder: URL? {
        didSet { defaults.set(gamesFolder?.path, forKey: Self.folderKey) }
    }

    @Published private(set) var prefs: [String: GamePrefs] {
        didSet {
            if let data = try? JSONEncoder().encode(prefs) { defaults.set(data, forKey: Self.prefsKey) }
        }
    }

    /// ROM file name → TitleID, remembered whenever a game is seen running.
    private(set) var knownTitleIDs: [String: String] {
        didSet { defaults.set(knownTitleIDs, forKey: Self.titleIDsKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showOnDiscord = defaults.object(forKey: Self.showKey) as? Bool ?? true
        gamesFolder = defaults.string(forKey: Self.folderKey).map { URL(fileURLWithPath: $0) }
        writeLog = defaults.bool(forKey: Self.logKey)
        idleMinutes = defaults.object(forKey: Self.idleKey) as? Int ?? 15
        detailsTemplate = defaults.string(forKey: Self.detailsKey)
        stateTemplate = defaults.string(forKey: Self.stateKey)
        showEShopButton = defaults.object(forKey: Self.eShopButtonKey) as? Bool ?? true
        customButtonLabel = defaults.string(forKey: Self.buttonLabelKey)
        customButtonURL = defaults.string(forKey: Self.buttonURLKey)
        prefs = defaults.data(forKey: Self.prefsKey)
            .flatMap { try? JSONDecoder().decode([String: GamePrefs].self, from: $0) } ?? [:]
        knownTitleIDs = defaults.dictionary(forKey: Self.titleIDsKey) as? [String: String] ?? [:]
    }

    func rememberTitleID(_ titleID: String, for romPath: String) {
        let key = Self.key(for: romPath)
        if knownTitleIDs[key] != titleID { knownTitleIDs[key] = titleID }
    }

    static func key(for romPath: String) -> String {
        (romPath as NSString).lastPathComponent
    }

    func prefs(for romPath: String) -> GamePrefs {
        prefs[Self.key(for: romPath)] ?? GamePrefs()
    }

    func isHidden(_ romPath: String) -> Bool {
        prefs(for: romPath).hidden
    }

    /// The custom name when set, else the detected one.
    func displayName(for romPath: String, detected: String) -> String {
        prefs(for: romPath).customName ?? detected
    }

    func setHidden(_ hidden: Bool, for romPath: String) {
        update(romPath) { $0.hidden = hidden }
    }

    func setCustomName(_ name: String?, for romPath: String) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        update(romPath) { $0.customName = (trimmed?.isEmpty ?? true) ? nil : trimmed }
    }

    private func update(_ romPath: String, _ change: (inout GamePrefs) -> Void) {
        var value = prefs(for: romPath)
        change(&value)
        prefs[Self.key(for: romPath)] = value == GamePrefs() ? nil : value
    }
}
