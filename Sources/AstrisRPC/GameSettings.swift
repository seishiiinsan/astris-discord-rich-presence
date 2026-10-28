import Foundation

/// User preferences shared by the menu, the presence and the Settings window.
/// Per-game settings are keyed by ROM file name, so they survive moving the games folder.
final class GameSettings: ObservableObject {
    struct GamePrefs: Codable, Equatable {
        var hidden = false
        var customName: String?
        /// https URL (shown on Discord too) or file URL of an image copied in Application Support (shown here only).
        var customCover: String?
        /// Per-game presence lines, over the global ones.
        var detailsTemplate: String?
        var stateTemplate: String?
        var hidePlayedTime = false

        init() {}

        // New fields must not break settings saved by older versions.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
            customName = try c.decodeIfPresent(String.self, forKey: .customName)
            customCover = try c.decodeIfPresent(String.self, forKey: .customCover)
            detailsTemplate = try c.decodeIfPresent(String.self, forKey: .detailsTemplate)
            stateTemplate = try c.decodeIfPresent(String.self, forKey: .stateTemplate)
            hidePlayedTime = try c.decodeIfPresent(Bool.self, forKey: .hidePlayedTime) ?? false
        }
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
    private static let favoritesKey = "favoriteGames"
    private static let hotKeysKey = "hotKeys"
    private static let importedFavoritesKey = "importedAstrisFavorites"
    private static let streamerKey = "streamerMode"
    private static let steamGridDBKeyKey = "steamGridDBKey"
    private static let preferSteamGridDBKey = "preferSteamGridDB"
    private static let notifyDiscordKey = "notifyDiscordLost"
    private static let notifyUpdatesKey = "notifyUpdates"
    private static let notifySummaryKey = "notifyWeeklySummary"
    private static let streamerPlayedKey = "streamerHidesPlayed"
    private static let streamerEShopKey = "streamerHidesEShop"
    private static let streamerCoverKey = "streamerHidesCover"

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

    /// Full ROM paths, in the order they were starred.
    @Published private(set) var favorites: [String] {
        didSet { defaults.set(favorites, forKey: Self.favoritesKey) }
    }

    func isFavorite(_ romPath: String) -> Bool {
        favorites.contains(romPath)
    }

    func setFavorite(_ on: Bool, for romPath: String) {
        favorites.removeAll { $0 == romPath }
        if on { favorites.append(romPath) }
    }

    /// TitleIDs already taken from Astris' favorites: un-starring one here sticks.
    private(set) var importedFavorites: Set<String> {
        didSet { defaults.set(Array(importedFavorites).sorted(), forKey: Self.importedFavoritesKey) }
    }

    /// Stars the games Astris marks as favorite, once each. Returns how many were added.
    @discardableResult
    func importAstrisFavorites(_ games: [GameLibrary.Game], astrisFavorites: Set<String>) -> Int {
        var added = 0
        for game in games {
            guard let id = game.titleID, astrisFavorites.contains(id), !importedFavorites.contains(id) else { continue }
            importedFavorites.insert(id)
            if !isFavorite(game.url.path) {
                setFavorite(true, for: game.url.path)
                added += 1
            }
        }
        return added
    }

    /// ⌃⌥⌘D / ⌃⌥⌘H anywhere in macOS.
    @Published var hotKeysEnabled: Bool {
        didSet { defaults.set(hotKeysEnabled, forKey: Self.hotKeysKey) }
    }

    /// Applied at next launch: menus are built once.
    @Published var language: L10n.Language {
        didSet { defaults.set(language.rawValue, forKey: L10n.languageKey) }
    }

    /// The user's own SteamGridDB API key (empty: source off).
    @Published var steamGridDBKey: String? {
        didSet { Self.store(steamGridDBKey, Self.steamGridDBKeyKey, in: defaults) }
    }

    /// Try SteamGridDB before the Switch art sources.
    @Published var preferSteamGridDB: Bool {
        didSet { defaults.set(preferSteamGridDB, forKey: Self.preferSteamGridDBKey) }
    }

    /// Cover from the resolved Switch art and SteamGridDB, in the chosen order.
    func pickCover(switchArt: () -> String?, steamGridDB: () -> String?) -> String? {
        guard let key = steamGridDBKey, !key.trimmingCharacters(in: .whitespaces).isEmpty else { return switchArt() }
        return preferSteamGridDB ? steamGridDB() ?? switchArt() : switchArt() ?? steamGridDB()
    }

    @Published var notifyDiscordLost: Bool {
        didSet { defaults.set(notifyDiscordLost, forKey: Self.notifyDiscordKey) }
    }

    @Published var notifyUpdates: Bool {
        didSet { defaults.set(notifyUpdates, forKey: Self.notifyUpdatesKey) }
    }

    @Published var notifyWeeklySummary: Bool {
        didSet { defaults.set(notifyWeeklySummary, forKey: Self.notifySummaryKey) }
    }

    /// Streamer mode: hides what's chosen below, on every game, in one switch.
    @Published var streamerMode: Bool {
        didSet { defaults.set(streamerMode, forKey: Self.streamerKey) }
    }

    @Published var streamerHidesPlayed: Bool {
        didSet { defaults.set(streamerHidesPlayed, forKey: Self.streamerPlayedKey) }
    }

    @Published var streamerHidesEShop: Bool {
        didSet { defaults.set(streamerHidesEShop, forKey: Self.streamerEShopKey) }
    }

    @Published var streamerHidesCover: Bool {
        didSet { defaults.set(streamerHidesCover, forKey: Self.streamerCoverKey) }
    }

    func hidesPlayedTime(_ romPath: String?) -> Bool {
        (streamerMode && streamerHidesPlayed) || (romPath.map { prefs(for: $0).hidePlayedTime } ?? false)
    }

    var hidesEShop: Bool { !showEShopButton || (streamerMode && streamerHidesEShop) }
    var hidesCover: Bool { streamerMode && streamerHidesCover }

    func setHidePlayedTime(_ hide: Bool, for romPath: String) {
        update(romPath) { $0.hidePlayedTime = hide }
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
        favorites = defaults.stringArray(forKey: Self.favoritesKey) ?? []
        importedFavorites = Set(defaults.stringArray(forKey: Self.importedFavoritesKey) ?? [])
        hotKeysEnabled = defaults.object(forKey: Self.hotKeysKey) as? Bool ?? true
        streamerMode = defaults.bool(forKey: Self.streamerKey)
        steamGridDBKey = defaults.string(forKey: Self.steamGridDBKeyKey)
        preferSteamGridDB = defaults.bool(forKey: Self.preferSteamGridDBKey)
        notifyDiscordLost = defaults.object(forKey: Self.notifyDiscordKey) as? Bool ?? true
        notifyUpdates = defaults.object(forKey: Self.notifyUpdatesKey) as? Bool ?? true
        notifyWeeklySummary = defaults.object(forKey: Self.notifySummaryKey) as? Bool ?? true
        streamerHidesPlayed = defaults.object(forKey: Self.streamerPlayedKey) as? Bool ?? true
        streamerHidesEShop = defaults.object(forKey: Self.streamerEShopKey) as? Bool ?? true
        streamerHidesCover = defaults.object(forKey: Self.streamerCoverKey) as? Bool ?? false
        language = L10n.Language(rawValue: defaults.string(forKey: L10n.languageKey) ?? "") ?? .system
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

    /// Lines for this game: its own, else the global ones (nil: default).
    func templates(for romPath: String?) -> (details: String?, state: String?) {
        let own = romPath.map(prefs(for:))
        return (own?.detailsTemplate ?? detailsTemplate, own?.stateTemplate ?? stateTemplate)
    }

    func setTemplates(details: String?, state: String?, for romPath: String) {
        func clean(_ s: String?) -> String? {
            let t = s?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (t?.isEmpty ?? true) ? nil : t
        }
        update(romPath) {
            $0.detailsTemplate = clean(details)
            $0.stateTemplate = clean(state)
        }
    }

    /// Web covers show on Discord; local ones only in the app.
    func discordCover(for romPath: String) -> String? {
        prefs(for: romPath).customCover.flatMap { Presence.isWebURL($0, max: 256) ? $0 : nil }
    }

    func setCustomCover(_ link: String?, for romPath: String) {
        let trimmed = link?.trimmingCharacters(in: .whitespacesAndNewlines)
        let old = prefs(for: romPath).customCover
        update(romPath) { $0.customCover = (trimmed?.isEmpty ?? true) ? nil : trimmed }
        // Drop the copy of a replaced local image.
        if let old, old != prefs(for: romPath).customCover, let url = URL(string: old), url.isFileURL,
           url.path.hasPrefix(Self.coversFolder?.path ?? "/nonexistent") {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static let coversFolder = AppPaths.support?.appendingPathComponent("Covers", isDirectory: true)

    /// Copies a picked image next to the settings, so it survives moving or deleting the original.
    func importCover(from file: URL, for romPath: String) throws {
        guard let folder = Self.coversFolder else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = ImageCache.fileName(for: Self.key(for: romPath) + UUID().uuidString) + "." + (file.pathExtension.isEmpty ? "png" : file.pathExtension)
        let target = folder.appendingPathComponent(name)
        try FileManager.default.copyItem(at: file, to: target)
        setCustomCover(target.absoluteString, for: romPath)
    }

    private func update(_ romPath: String, _ change: (inout GamePrefs) -> Void) {
        var value = prefs(for: romPath)
        change(&value)
        prefs[Self.key(for: romPath)] = value == GamePrefs() ? nil : value
    }
}
