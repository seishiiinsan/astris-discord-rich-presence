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
    private let settingsItem = NSMenuItem(title: L10n.tr("Réglages…", "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
    private let updateItem = NSMenuItem(title: "", action: #selector(confirmUpdate), keyEquivalent: "")
    private let recentsItem = NSMenuItem(title: L10n.tr("Jeux récents", "Recent Games"), action: nil, keyEquivalent: "")
    private let checkItem = NSMenuItem(title: L10n.tr("Rechercher les mises à jour…", "Check for Updates…"), action: #selector(checkForUpdates), keyEquivalent: "")
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
        setUpMenu()
        // Settings window edits apply right away.
        settingsObserver = settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.tick() }
        }
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
        discordQueue.sync {
            if discord.isConnected { _ = discord.setActivity(nil) }
            discord.disconnect()
        }
    }

    // MARK: - Loop

    /// Polls only while Astris runs; otherwise waits for launch notifications.
    private func astrisChanged() {
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
                let played = game.playedTime.flatMap(Self.formatPlayed)
                presence = Presence(
                    details: name,
                    state: played.map { L10n.tr("Sur Astris · \($0) jouées", "On Astris · \($0) played") } ?? L10n.tr("Sur Astris", "On Astris"),
                    start: game.start,
                    image: game.titleID.flatMap(covers.cover(for:)) ?? Self.astrisLogo,
                    imageText: name,
                    buttons: [
                        (L10n.tr("Voir sur l'eShop", "View on eShop"), eShop.url(titleID: game.titleID, name: game.name)),
                        ("Astris", Self.astrisURL),
                    ])
            } else {
                presence = Presence(
                    details: L10n.tr("Dans le menu", "In the menu"), state: L10n.tr("Sur Astris", "On Astris"), start: astris.launchDate,
                    image: Self.astrisLogo, imageText: "Astris",
                    buttons: [("Astris", Self.astrisURL)])
            }
        }

        push(presence)
        refreshMenu(astrisRunning: astris != nil)
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
                    // Discord closed: back off 3 s → 6 → 12 … up to 60 s.
                    nextConnectAttempt = Date().addingTimeInterval(connectBackoff)
                    connectBackoff = min(connectBackoff * 2, 60)
                    return
                }
                connectBackoff = 3
                DispatchQueue.main.async { self.discordError = nil }
            }
            switch discord.setActivity(presence?.activity) {
            case .ok:
                sentPresence = presence
                hasSent = true
                DispatchQueue.main.async { self.discordError = nil }
            case .rejected(let message):
                // Don't resend the same refused presence every 3 s.
                sentPresence = presence
                hasSent = true
                DispatchQueue.main.async { self.discordError = message }
            case .failed:
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
        menu.addItem(.separator())

        // Settings.
        enabledItem.image = Self.symbol("eye")
        settingsItem.image = Self.symbol("gearshape")
        for item in [enabledItem, settingsItem] {
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
        let submenu = recentsItem.submenu ?? NSMenu()
        submenu.removeAllItems()
        recentsItem.isEnabled = !recents.entries.isEmpty
        for entry in recents.entries {
            let item = NSMenuItem(title: settings.displayName(for: entry.romPath, detected: entry.name), action: #selector(openRecent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = entry.romPath
            item.toolTip = entry.romPath
            item.isEnabled = FileManager.default.fileExists(atPath: entry.romPath)
            if let id = entry.titleID {
                item.image = thumbnails[id] ?? Self.symbol("gamecontroller")
                loadThumbnail(id)
            } else {
                item.image = Self.symbol("gamecontroller")
            }
            submenu.addItem(item)
        }
    }

    /// Downloads the cover once and keeps a menu-sized copy for next time the menu opens.
    private func loadThumbnail(_ titleID: String) {
        guard thumbnails[titleID] == nil, !loadingThumbnails.contains(titleID),
              let link = covers.cover(for: titleID), let url = URL(string: link) else { return }
        loadingThumbnails.insert(titleID)
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let image = data.flatMap(NSImage.init(data:))
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                loadingThumbnails.remove(titleID)
                guard let image else { return }
                image.size = NSSize(width: 20, height: 20)
                thumbnails[titleID] = image
            }
        }.resume()
    }

    @objc private func openRecent(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        let astrisApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "V380-Ori.Astris")
            ?? URL(fileURLWithPath: "/Applications/Astris.app")
        NSWorkspace.shared.open([URL(fileURLWithPath: path)], withApplicationAt: astrisApp, configuration: .init()) { _, error in
            guard let error else { return }
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                NSAlert(error: error).runModal()
            }
        }
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
            gameItem.subtitle = detector.game?.playedTime.flatMap(Self.formatPlayed).map { L10n.tr("\($0) jouées avant cette session", "\($0) played before this session") }
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
        tick()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(settings: settings, covers: covers, recents: recents)
        }
        settingsWindow?.show()
    }

    // MARK: - Updates

    private func checkUpdates(manual: Bool) {
        updater.check { [weak self] result in
            guard let self else { return }
            if case .failure(let error) = result {
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
