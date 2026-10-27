import AppKit
import ServiceManagement

struct Presence: Equatable {
    var details: String
    var state: String?
    var start: Date?
    var image: String?
    var imageText: String?
    var buttons: [(label: String, url: String)] = []

    static func == (a: Presence, b: Presence) -> Bool {
        a.details == b.details && a.state == b.state && a.start == b.start
            && a.image == b.image && a.imageText == b.imageText
            && a.buttons.map { $0.label } == b.buttons.map { $0.label } && a.buttons.map { $0.url } == b.buttons.map { $0.url }
    }

    var activity: [String: Any] {
        var a: [String: Any] = ["type": 0, "details": details]
        if let state { a["state"] = state }
        if let start { a["timestamps"] = ["start": Int(start.timeIntervalSince1970)] }
        if let image {
            var assets: [String: Any] = ["large_image": image]
            if let imageText { assets["large_text"] = imageText }
            a["assets"] = assets
        }
        if !buttons.isEmpty {
            a["buttons"] = buttons.prefix(2).map { ["label": $0.label, "url": $0.url] }
        }
        return a
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let clientID = "1564590186887774209"
    private static let enabledKey = "presenceEnabled"
    private static let astrisLogo =
        "https://raw.githubusercontent.com/seishiiinsan/astris-discord-rich-presence/main/Resources/AstrisLogo.png"

    private static let astrisURL = "https://github.com/V380-Ori/Astris.Binaries"

    private let detector = GameDetector()
    private let covers = CoverResolver()
    private let updater = Updater()
    private var availableUpdate: Updater.Release?
    private let discord = DiscordIPC(clientID: AppDelegate.clientID)
    private let discordQueue = DispatchQueue(label: "astris-rpc.discord")

    // Touched only on discordQueue.
    private var sentPresence: Presence?
    private var hasSent = false

    private var statusItem: NSStatusItem!
    private let gameItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let discordItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let enabledItem = NSMenuItem(title: "Activer Rich Presence", action: #selector(toggleEnabled), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Lancer au démarrage", action: #selector(toggleLogin), keyEquivalent: "")
    private let updateItem = NSMenuItem(title: "", action: #selector(installUpdate), keyEquivalent: "")
    private let checkItem = NSMenuItem(title: "Rechercher les mises à jour…", action: #selector(checkForUpdates), keyEquivalent: "")
    private var discordConnected = false
    private var timer: Timer?
    private var updateTimer: Timer?

    private var enabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGPIPE, SIG_IGN)
        setUpMenu()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.tick() }
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

    private func tick() {
        let astris = runningAstris()
        if let astris { detector.poll(pid: astris.processIdentifier) } else { detector.reset() }

        var presence: Presence?
        if enabled, let astris {
            if let game = detector.game {
                let played = game.playedTime.flatMap(Self.formatPlayed)
                presence = Presence(
                    details: game.name,
                    state: played.map { "Sur Astris · \($0) jouées" } ?? "Sur Astris",
                    start: game.start,
                    image: game.titleID.flatMap(covers.cover(for:)) ?? Self.astrisLogo,
                    imageText: game.name,
                    buttons: [
                        ("Voir sur l'eShop", Self.eShopURL(for: game.name)),
                        ("Astris", Self.astrisURL),
                    ])
            } else {
                presence = Presence(
                    details: "Dans le menu", state: "Sur Astris", start: astris.launchDate,
                    image: Self.astrisLogo, imageText: "Astris",
                    buttons: [("Astris", Self.astrisURL)])
            }
        }

        push(presence)
        refreshMenu(astrisRunning: astris != nil)
    }

    /// "45 min", "12 h"
    private static func formatPlayed(_ seconds: TimeInterval) -> String? {
        guard seconds >= 60 else { return nil }
        if seconds < 3600 { return "\(Int(seconds / 60)) min" }
        return "\(Int(seconds / 3600)) h"
    }

    private static func eShopURL(for name: String) -> String {
        let query = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "https://www.nintendo.com/fr-fr/Rechercher/Rechercher-299117.html?q=\(query)"
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
            guard discord.connect() else { return }
            if discord.setActivity(presence?.activity) {
                sentPresence = presence
                hasSent = true
            } else {
                hasSent = false
            }
        }
    }

    private func runningAstris() -> NSRunningApplication? {
        let me = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.first { app in
            guard app.processIdentifier != me else { return false }
            let name = app.localizedName?.lowercased() ?? ""
            let bundle = app.bundleIdentifier?.lowercased() ?? ""
            return name == "astris" || (bundle.contains("astris") && !bundle.contains("astris-rpc"))
        }
    }

    // MARK: - Menu

    private func setUpMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "gamecontroller", accessibilityDescription: "Astris RPC")

        let menu = NSMenu()
        menu.autoenablesItems = false
        gameItem.isEnabled = false
        discordItem.isEnabled = false
        menu.addItem(gameItem)
        menu.addItem(discordItem)
        menu.addItem(.separator())
        for item in [enabledItem, loginItem] {
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        updateItem.target = self
        updateItem.isHidden = true
        checkItem.target = self
        menu.addItem(updateItem)
        menu.addItem(checkItem)
        let versionItem = NSMenuItem(title: "Version \(Updater.currentVersion)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func refreshMenu(astrisRunning: Bool) {
        if !astrisRunning {
            gameItem.title = "Astris non lancé"
        } else if let game = detector.game {
            gameItem.title = "Jeu : \(game.name)"
        } else {
            gameItem.title = "Astris : menu"
        }
        discordItem.title = discordConnected ? "Discord : connecté" : "Discord : non connecté"
        enabledItem.state = enabled ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        tick()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
        refreshMenu(astrisRunning: runningAstris() != nil)
    }

    // MARK: - Updates

    private func checkUpdates(manual: Bool) {
        updater.check { [weak self] release in
            guard let self else { return }
            availableUpdate = release
            if let release {
                updateItem.title = "Mettre à jour vers v\(release.version)"
                updateItem.isHidden = false
            } else {
                updateItem.isHidden = true
            }
            guard manual else { return }
            let alert = NSAlert()
            if let release {
                alert.messageText = "Version \(release.version) disponible"
                alert.addButton(withTitle: "Mettre à jour")
                alert.addButton(withTitle: "Plus tard")
            } else {
                alert.messageText = "Astris RPC est à jour (v\(Updater.currentVersion))"
            }
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn, release != nil { installUpdate() }
        }
    }

    @objc private func checkForUpdates() {
        checkUpdates(manual: true)
    }

    @objc private func installUpdate() {
        guard let release = availableUpdate else { return }
        updateItem.title = "Téléchargement de v\(release.version)…"
        updateItem.isEnabled = false
        updater.install(release) { [weak self] error in
            guard let self else { return }
            updateItem.title = "Mettre à jour vers v\(release.version)"
            updateItem.isEnabled = true
            if let error {
                NSApp.activate(ignoringOtherApps: true)
                NSAlert(error: error).runModal()
            }
        }
    }
}
