import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let clientID = "1564590186887774209"
    private static let astrisLogo =
        "https://raw.githubusercontent.com/seishiiinsan/astris-discord-rich-presence/main/Resources/AstrisLogo.png"

    private static let astrisURL = "https://github.com/V380-Ori/Astris.Binaries"

    private let detector = GameDetector()
    private let covers = CoverResolver()
    private let eShop = EShopResolver()
    private let recents = RecentGames()
    private let idle = IdleMonitor()
    private let history = PlayHistory()
    private var isIdle = false
    private var thumbnails: [String: NSImage] = [:]
    private var loadingThumbnails: Set<String> = []
    private let updater = Updater()
    private var availableUpdate: Updater.Release?
    private let discord = DiscordIPC(clientID: AppDelegate.clientID)
    private let discordQueue = DispatchQueue(label: "astris-rpc.discord")

    // Touched only on discordQueue.
    private var sentPresence: Presence?
    private var hasSent = false
    private var nextConnectAttempt = Date.distantPast
    private var connectBackoff: TimeInterval = 3

    private var astris: NSRunningApplication?
    private var iconSymbol: String?

    private var statusItem: NSStatusItem!
    private let gameItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let discordItem = NSMenuItem(title: "", action: #selector(openDiscord), keyEquivalent: "")
    private let enabledItem = NSMenuItem(title: L10n.tr("Afficher sur Discord", "Show on Discord"), action: #selector(toggleEnabled), keyEquivalent: "")
    private let hideGameItem = NSMenuItem(title: L10n.tr("Masquer ce jeu sur Discord", "Hide This Game on Discord"), action: #selector(toggleHideGame), keyEquivalent: "")
    private let hotKeys = HotKeys()
    private let settingsItem = NSMenuItem(title: L10n.tr("Réglages…", "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
    private let updateItem = NSMenuItem(title: "", action: #selector(confirmUpdate), keyEquivalent: "")
    private let recentsItem = NSMenuItem(title: L10n.tr("Jeux récents", "Recent Games"), action: nil, keyEquivalent: "")
    private let favoritesItem = NSMenuItem(title: L10n.tr("Favoris", "Favorites"), action: nil, keyEquivalent: "")
    private let checkItem = NSMenuItem(title: L10n.tr("Rechercher les mises à jour…", "Check for Updates…"), action: #selector(checkForUpdates), keyEquivalent: "")
    private let diagnosticItem = NSMenuItem(title: L10n.tr("Copier le diagnostic", "Copy Diagnostics"), action: #selector(copyDiagnostic), keyEquivalent: "")
    /// Last presence built by `tick`, for the diagnostic.
    private var lastPresence: Presence?
    private var loggedGame: String?
    private var discordConnected = false
    /// Last refusal from Discord for the current presence, shown in the menu.
    private var discordError: String?
    private var timer: Timer?
    private var updateTimer: Timer?

    private let settings = GameSettings.shared
    private var settingsWindow: SettingsWindowController?
    private var settingsObserver: AnyCancellable?

    private var enabled: Bool {
        get { settings.showOnDiscord }
        set { settings.showOnDiscord = newValue }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGPIPE, SIG_IGN)
        Log.shared.toFile = settings.writeLog
        Log.shared.add("Astris RPC \(Updater.currentVersion) started, macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        setUpMenu()
        // Settings window edits apply right away.
        settingsObserver = settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.syncHotKeys()
                self?.tick()
            }
        }
        hotKeys.onAction = { [weak self] action in
            switch action {
            case .toggleDiscord: self?.toggleEnabled()
            case .toggleHideGame: self?.toggleHideGame()
            }
        }
        syncHotKeys()
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(appLaunched(_:)),
                           name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(appTerminated(_:)),
                           name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        astris = NSWorkspace.shared.runningApplications.first(where: isAstris)
        astrisChanged()
        checkUpdates(manual: false)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            self?.checkUpdates(manual: false)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        history.save()
        discordQueue.sync {
            if discord.isConnected { _ = discord.setActivity(nil) }
            discord.disconnect()
        }
    }

    // MARK: - Loop

    /// Polls only while Astris runs; otherwise waits for launch notifications.
    private func astrisChanged() {
        Log.shared.add(astris.map { "Astris running (pid \($0.processIdentifier), \($0.bundleIdentifier ?? "no bundle id"))" } ?? "Astris not running")
        timer?.invalidate()
        timer = nil
        if astris != nil {
            timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.tick() }
        }
        tick()
    }

    @objc private func appLaunched(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        if isAstris(app) {
            astris = app
            astrisChanged()
        } else if app.bundleIdentifier?.lowercased().hasPrefix("com.hnc.discord") == true {
            // Discord is back: reconnect right away instead of waiting for the backoff.
            discordQueue.async { [self] in
                nextConnectAttempt = .distantPast
                connectBackoff = 3
            }
            tick()
        }
    }

    @objc private func appTerminated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier == astris?.processIdentifier else { return }
        astris = NSWorkspace.shared.runningApplications.first(where: isAstris)
        astrisChanged()
    }

    private func tick() {
        if let astris { detector.poll(pid: astris.processIdentifier) } else { detector.reset() }
        if let titleID = detector.game?.titleID, let rom = detector.romPath {
            settings.rememberTitleID(titleID, for: rom)
        }
        let gameKey = detector.romPath
        if gameKey != loggedGame {
            loggedGame = gameKey
            if let game = detector.game, let rom = gameKey {
                Log.shared.add("Game: \(game.name) [\(game.titleID ?? "no TitleID")] \((rom as NSString).lastPathComponent)")
            } else if astris != nil {
                Log.shared.add("No game running")
            }
        }
        if let game = detector.game, let rom = detector.romPath, recents.entries.first?.romPath != rom {
            recents.record(name: game.name, titleID: game.titleID, romPath: rom)
        }

        var presence: Presence?
        if enabled, let astris {
            if let game = detector.game, let rom = detector.romPath, settings.isHidden(rom) {
                // Blacklisted: say we're playing, never what.
                presence = Presence(
                    details: L10n.tr("En jeu", "Playing"), state: L10n.tr("Sur Astris", "On Astris"), start: game.start,
                    image: Self.astrisLogo, imageText: "Astris",
                    buttons: [("Astris", Self.astrisURL)])
            } else if let game = detector.game {
                let name = detector.romPath.map { settings.displayName(for: $0, detected: game.name) } ?? game.name
                // "1.2.0" -> "v1.2.0"; "update 3" stays as is.
                let version = game.version.map { $0.first?.isNumber == true ? "v\($0)" : $0 }
                let values: [String: String?] = [
                    "game": name,
                    "played": game.playedTime.flatMap(Self.formatPlayed),
                    "version": version,
                ]
                var buttons: [(label: String, url: String)] = []
                if settings.showEShopButton {
                    buttons.append((L10n.tr("Voir sur l'eShop", "View on eShop"), eShop.url(titleID: game.titleID, name: game.name)))
                }
                buttons.append(settings.customButton ?? ("Astris", Self.astrisURL))
                let cover = detector.romPath.flatMap(settings.discordCover(for:)) ?? game.titleID.flatMap(covers.cover(for:))
                presence = Presence(
                    details: PresenceTemplate.render(Self.template(settings.detailsTemplate, PresenceTemplate.defaultDetails), values: values) ?? name,
                    state: PresenceTemplate.render(Self.template(settings.stateTemplate, PresenceTemplate.defaultState), values: values),
                    start: game.start,
                    image: cover ?? Self.astrisLogo,
                    imageText: name,
                    // Astris badge on the cover, with the game version when known.
                    smallImage: cover == nil ? nil : Self.astrisLogo,
                    smallText: version.map { "Astris · \($0)" } ?? "Astris",
                    buttons: buttons)
            } else {
                presence = Presence(
                    details: L10n.tr("Dans le menu", "In the menu"), state: L10n.tr("Sur Astris", "On Astris"), start: astris.launchDate,
                    image: Self.astrisLogo, imageText: "Astris",
                    buttons: [("Astris", Self.astrisURL)])
            }
        }

        let wasIdle = isIdle
        isIdle = detector.game != nil && IdleMonitor.isIdle(idleTime: idle.idleTime, afterMinutes: settings.idleMinutes)
        if isIdle != wasIdle { Log.shared.add(isIdle ? "Idle" : "Back from idle") }
        let played = isIdle ? nil : detector.game
        history.update(name: played?.name, titleID: played?.titleID, romPath: played == nil ? nil : detector.romPath)
        if isIdle, presence != nil {
            // Paused: no running clock.
            presence?.state = L10n.tr("En pause · Sur Astris", "Idle · On Astris")
            presence?.start = nil
        }

        lastPresence = presence
        push(presence)
        refreshMenu(astrisRunning: astris != nil)
    }

    private static func template(_ custom: String?, _ fallback: String) -> String {
        guard let custom, !custom.trimmingCharacters(in: .whitespaces).isEmpty else { return fallback }
        return custom
    }

    /// "45 min", "12 h"
    static func formatPlayed(_ seconds: TimeInterval) -> String? {
        guard seconds >= 60 else { return nil }
        if seconds < 3600 { return "\(Int(seconds / 60)) min" }
        return "\(Int(seconds / 3600)) h"
    }

    private func push(_ presence: Presence?) {
        discordQueue.async { [self] in
            defer {
                let connected = discord.isConnected
                DispatchQueue.main.async { self.discordConnected = connected }
            }
            if hasSent && presence == sentPresence && (presence == nil || discord.isConnected) { return }
            if presence == nil && !discord.isConnected {
                sentPresence = nil
                hasSent = true
                return
            }
            if !discord.isConnected {
                guard Date() >= nextConnectAttempt else { return }
                guard discord.connect() else {
                    if connectBackoff == 3 { Log.shared.add("Discord unreachable, retrying") }
                    // Discord closed: back off 3 s → 6 → 12 … up to 60 s.
                    nextConnectAttempt = Date().addingTimeInterval(connectBackoff)
                    connectBackoff = min(connectBackoff * 2, 60)
                    return
                }
                connectBackoff = 3
                Log.shared.add("Connected to Discord")
                DispatchQueue.main.async { self.discordError = nil }
            }
            switch discord.setActivity(presence?.activity) {
            case .ok:
                sentPresence = presence
                hasSent = true
                DispatchQueue.main.async { self.discordError = nil }
            case .rejected(let message):
                Log.shared.add("Discord rejected the presence: \(message)")
                // Don't resend the same refused presence every 3 s.
                sentPresence = presence
                hasSent = true
                DispatchQueue.main.async { self.discordError = message }
            case .failed:
                Log.shared.add("Discord connection lost")
                hasSent = false
            }
        }
    }

    private func isAstris(_ app: NSRunningApplication) -> Bool {
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier, !app.isTerminated else { return false }
        let name = app.localizedName?.lowercased() ?? ""
        let bundle = app.bundleIdentifier?.lowercased() ?? ""
        return name == "astris" || (bundle.contains("astris") && !bundle.contains("astris-rpc"))
    }

    // MARK: - Menu

    private func setUpMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        // Status: what is happening right now.
        gameItem.isEnabled = false
        discordItem.target = self
        menu.addItem(gameItem)
        menu.addItem(discordItem)
        menu.addItem(.separator())

        // Shortcuts.
        recentsItem.image = Self.symbol("clock.arrow.circlepath")
        recentsItem.submenu = NSMenu()
        menu.addItem(recentsItem)
        favoritesItem.image = Self.symbol("star")
        favoritesItem.submenu = NSMenu()
        favoritesItem.isHidden = settings.favorites.isEmpty
        menu.addItem(favoritesItem)
        menu.addItem(.separator())

        // Settings.
        enabledItem.image = Self.symbol("eye")
        hideGameItem.image = Self.symbol("eye.slash")
        settingsItem.image = Self.symbol("gearshape")
        for item in [enabledItem, hideGameItem, settingsItem] {
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())

        // Updates.
        updateItem.target = self
        updateItem.isHidden = true
        updateItem.image = Self.symbol("arrow.down.circle.fill", color: .controlAccentColor)
        checkItem.target = self
        checkItem.image = Self.symbol("arrow.triangle.2.circlepath")
        menu.addItem(updateItem)
        menu.addItem(checkItem)
        let versionItem = NSMenuItem(title: "Astris RPC \(Updater.currentVersion)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        diagnosticItem.target = self
        diagnosticItem.image = Self.symbol("stethoscope")
        menu.addItem(diagnosticItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: L10n.tr("Quitter Astris RPC", "Quit Astris RPC"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        refreshMenu(astrisRunning: astris != nil)
    }

    /// Always show fresh state when the menu opens, even while polling is paused.
    func menuWillOpen(_ menu: NSMenu) {
        refreshMenu(astrisRunning: astris != nil)
        refreshRecents()
    }

    // MARK: - Recent games

    private func refreshRecents() {
        fill(recentsItem, with: recents.entries.map { (path: $0.romPath, name: $0.name, titleID: $0.titleID) })
        fill(favoritesItem, with: settings.favorites.map { path -> (path: String, name: String, titleID: String?) in
            let file = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
            let titleID = GameDetector.titleID(in: file)?.uppercased() ?? settings.knownTitleIDs[GameSettings.key(for: path)]
            return (path: path, name: GameDetector.cleanName(file), titleID: titleID)
        })
        favoritesItem.isHidden = settings.favorites.isEmpty
    }

    /// One item per game, with its cover; a click opens it in Astris.
    private func fill(_ parent: NSMenuItem, with games: [(path: String, name: String, titleID: String?)]) {
        let submenu = parent.submenu ?? NSMenu()
        submenu.removeAllItems()
        parent.isEnabled = !games.isEmpty
        for game in games {
            let item = NSMenuItem(title: settings.displayName(for: game.path, detected: game.name), action: #selector(openRecent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = game.path
            item.toolTip = game.path
            item.isEnabled = FileManager.default.fileExists(atPath: game.path)
            if let custom = settings.prefs(for: game.path).customCover {
                item.image = thumbnails[custom] ?? Self.symbol("gamecontroller")
                loadThumbnail(key: custom, link: custom)
            } else if let id = game.titleID {
                item.image = thumbnails[id] ?? Self.symbol("gamecontroller")
                if let link = covers.cover(for: id) { loadThumbnail(key: id, link: link) }
            } else {
                item.image = Self.symbol("gamecontroller")
            }
            submenu.addItem(item)
        }
    }

    /// Loads the cover (from the disk cache when possible) and keeps a menu-sized copy.
    private func loadThumbnail(key: String, link: String) {
        guard thumbnails[key] == nil, !loadingThumbnails.contains(key) else { return }
        loadingThumbnails.insert(key)
        ImageCache.shared.image(for: link) { [weak self] image in
            guard let self else { return }
            loadingThumbnails.remove(key)
            guard let thumb = image?.copy() as? NSImage else { return }
            thumb.size = NSSize(width: 20, height: 20)
            thumbnails[key] = thumb
        }
    }

    @objc private func openRecent(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        AstrisLauncher.open(path)
    }

    private func refreshMenu(astrisRunning: Bool) {
        if !astrisRunning {
            gameItem.title = L10n.tr("Astris n'est pas ouvert", "Astris isn't open")
            gameItem.image = Self.symbol("moon.zzz")
        } else if let game = detector.game {
            gameItem.title = game.name
            gameItem.image = Self.symbol("gamecontroller.fill", color: .systemGreen)
        } else {
            gameItem.title = L10n.tr("Astris ouvert, aucun jeu lancé", "Astris open, no game running")
            gameItem.image = Self.symbol("gamecontroller")
        }
        if #available(macOS 14.4, *) {
            gameItem.subtitle = isIdle
                ? L10n.tr("En pause sur Discord", "Idle on Discord")
                : detector.game?.playedTime.flatMap(Self.formatPlayed).map { L10n.tr("\($0) jouées avant cette session", "\($0) played before this session") }
        }

        // Discord row doubles as the fix: click to open Discord when it isn't running.
        // Without Astris there's nothing to show, so no IPC connection: judge by the running app.
        discordItem.toolTip = nil
        if #available(macOS 14.4, *) { discordItem.subtitle = nil }
        if discordConnected, let discordError {
            discordItem.title = L10n.tr("Discord a refusé l'affichage", "Discord rejected the presence")
            discordItem.image = Self.symbol("exclamationmark.circle.fill", color: .systemOrange)
            discordItem.toolTip = discordError
            if #available(macOS 14.4, *) { discordItem.subtitle = discordError }
            discordItem.isEnabled = false
        } else if discordConnected {
            discordItem.title = L10n.tr("Connecté à Discord", "Connected to Discord")
            discordItem.image = Self.symbol("checkmark.circle.fill", color: .systemGreen)
            discordItem.isEnabled = false
        } else if Self.isDiscordRunning() {
            discordItem.title = astrisRunning
                ? L10n.tr("Connexion à Discord…", "Connecting to Discord…")
                : L10n.tr("Discord ouvert", "Discord open")
            discordItem.image = Self.symbol("checkmark.circle", color: .secondaryLabelColor)
            discordItem.isEnabled = false
        } else {
            discordItem.title = L10n.tr("Discord fermé — Ouvrir Discord", "Discord closed — Open Discord")
            discordItem.image = Self.symbol("exclamationmark.triangle.fill", color: .systemOrange)
            discordItem.isEnabled = true
        }

        enabledItem.state = enabled ? .on : .off
        hideGameItem.isHidden = detector.game == nil
        hideGameItem.state = detector.romPath.map(settings.isHidden) == true ? .on : .off
        let shortcutMask: NSEvent.ModifierFlags = [.control, .option, .command]
        for (item, action) in [(enabledItem, HotKeys.Action.toggleDiscord), (hideGameItem, .toggleHideGame)] {
            // Shown as a hint; the global hot key does the work.
            item.keyEquivalent = hotKeys.isRegistered ? HotKeys.keyEquivalent(action) : ""
            item.keyEquivalentModifierMask = shortcutMask
        }
        refreshIcon(astrisRunning: astrisRunning)
    }

    private static func symbol(_ name: String, color: NSColor? = nil) -> NSImage? {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        guard let color else { return image }
        return image.withSymbolConfiguration(.init(paletteColors: [color]))
    }

    /// Filled controller in game, outline otherwise, dimmed when idle, warning if Discord is unreachable.
    private func refreshIcon(astrisRunning: Bool) {
        let (symbol, label): (String, String) = {
            if !enabled { return ("gamecontroller", L10n.tr("Astris RPC — désactivé", "Astris RPC — off")) }
            if astrisRunning && !discordConnected && !Self.isDiscordRunning() { return ("exclamationmark.triangle", L10n.tr("Astris RPC — Discord injoignable", "Astris RPC — Discord unreachable")) }
            if let game = detector.game { return ("gamecontroller.fill", "Astris RPC — \(game.name)") }
            return ("gamecontroller", astrisRunning ? L10n.tr("Astris RPC — menu Astris", "Astris RPC — Astris menu") : L10n.tr("Astris RPC — Astris fermé", "Astris RPC — Astris closed"))
        }()
        guard let button = statusItem.button else { return }
        if symbol != iconSymbol {
            iconSymbol = symbol
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        }
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.appearsDisabled = !enabled || !astrisRunning
    }

    static func isDiscordRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier?.lowercased().hasPrefix("com.hnc.discord") == true
        }
    }

    @objc private func openDiscord() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.hnc.Discord") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        Log.shared.add(enabled ? "Presence on" : "Presence off")
        tick()
    }

    /// Blacklists (or not) the game being played, without opening Settings.
    @objc private func toggleHideGame() {
        guard let rom = detector.romPath else { NSSound.beep(); return }
        settings.setHidden(!settings.isHidden(rom), for: rom)
        Log.shared.add(settings.isHidden(rom) ? "Current game hidden" : "Current game shown")
        tick()
    }

    private func syncHotKeys() {
        if settings.hotKeysEnabled && !hotKeys.isRegistered {
            hotKeys.register()
        } else if !settings.hotKeysEnabled && hotKeys.isRegistered {
            hotKeys.unregister()
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(settings: settings, covers: covers, recents: recents, history: history)
        }
        settingsWindow?.show()
    }

    // MARK: - Diagnostic

    @objc private func copyDiagnostic() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostic(), forType: .string)
        Log.shared.add("Diagnostic copied")
    }

    /// Plain-text report to paste in a GitHub issue. File names only, never full paths.
    func diagnostic() -> String {
        var lines = [
            "Astris RPC \(Updater.currentVersion)",
            "macOS \(ProcessInfo.processInfo.operatingSystemVersionString), \(Locale.preferredLanguages.first ?? "?")",
            "",
            "Show on Discord: \(enabled)",
            "Astris: " + (astris.map { "running, pid \($0.processIdentifier), \($0.bundleIdentifier ?? "no bundle id")" } ?? "not running"),
            "Discord: " + (discordConnected ? "connected" : Self.isDiscordRunning() ? "open, not connected" : "closed"),
        ]
        if let discordError { lines.append("Discord error: \(discordError)") }
        if let game = detector.game {
            lines.append("Game: \(game.name)")
            lines.append("TitleID: \(game.titleID ?? "none")")
            lines.append("Version: \(game.version ?? "unknown")")
            lines.append("ROM: \(detector.romPath.map { ($0 as NSString).lastPathComponent } ?? "?")")
            lines.append("Played before: \(game.playedTime.flatMap(Self.formatPlayed) ?? "unknown")")
            lines.append("Idle: \(isIdle) (\(Int(idle.idleTime)) s without input, threshold \(settings.idleMinutes) min)")
            if let id = game.titleID {
                lines.append("Cover: \(covers.cover(for: id) ?? "none yet")")
                lines.append("Cover sources: " + CoverResolver.candidates(for: id).joined(separator: ", "))
            }
            if let rom = detector.romPath { lines.append("Hidden: \(settings.isHidden(rom))") }
        } else {
            lines.append("Game: none")
        }
        if let p = lastPresence {
            lines.append("Presence: \(p.details) | \(p.state ?? "-") | image: \(p.image ?? "-")")
        }
        lines.append("Astris folders: " + GameDetector.astrisGamesDirectories
            .map { "\($0.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")) (\(FileManager.default.fileExists(atPath: $0.path) ? "found" : "missing"))" }
            .joined(separator: ", "))
        lines.append("Image cache: \(ImageCache.shared.diskSize / 1024) KB")
        lines.append("")
        lines.append("Log:")
        lines.append(contentsOf: Log.shared.recent.suffix(60))
        return lines.joined(separator: "\n")
    }

    // MARK: - Updates

    private func checkUpdates(manual: Bool) {
        updater.check { [weak self] result in
            guard let self else { return }
            if case .failure(let error) = result {
                Log.shared.add("Update check failed: \(error.localizedDescription)")
                if manual {
                    NSApp.activate(ignoringOtherApps: true)
                    let alert = NSAlert()
                    alert.messageText = L10n.tr("Impossible de vérifier les mises à jour", "Couldn't check for updates")
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
                return
            }
            let release = try? result.get()
            availableUpdate = release
            if let release {
                updateItem.title = L10n.tr("Mettre à jour vers v\(release.version)", "Update to v\(release.version)")
                updateItem.isHidden = false
            } else {
                updateItem.isHidden = true
            }
            guard manual else { return }
            if release != nil {
                confirmUpdate()
            } else {
                let alert = NSAlert()
                alert.messageText = L10n.tr("Astris RPC est à jour (v\(Updater.currentVersion))", "Astris RPC is up to date (v\(Updater.currentVersion))")
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        }
    }

    /// Shows the release notes, then installs if confirmed.
    @objc private func confirmUpdate() {
        guard let release = availableUpdate else { return }
        let alert = NSAlert()
        alert.messageText = L10n.tr("Version \(release.version) disponible", "Version \(release.version) available")
        alert.informativeText = release.notes ?? ""
        alert.addButton(withTitle: L10n.tr("Mettre à jour", "Update"))
        alert.addButton(withTitle: L10n.tr("Plus tard", "Later"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { installUpdate() }
    }

    @objc private func checkForUpdates() {
        checkUpdates(manual: true)
    }

    private func installUpdate() {
        guard let release = availableUpdate else { return }
        updateItem.title = L10n.tr("Téléchargement de v\(release.version)…", "Downloading v\(release.version)…")
        updateItem.isEnabled = false
        updater.install(release) { [weak self] error in
            guard let self else { return }
            updateItem.title = L10n.tr("Mettre à jour vers v\(release.version)", "Update to v\(release.version)")
            updateItem.isEnabled = true
            if let error {
                NSApp.activate(ignoringOtherApps: true)
                NSAlert(error: error).runModal()
            }
        }
    }
}
