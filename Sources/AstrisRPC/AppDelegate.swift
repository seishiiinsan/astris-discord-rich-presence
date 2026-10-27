import AppKit
import ServiceManagement

struct Presence: Equatable {
    var details: String
    var state: String?
    var start: Date?
    var image: String?
    var imageText: String?
    var smallImage: String?
    var smallText: String?

    var activity: [String: Any] {
        var a: [String: Any] = ["type": 0, "details": details]
        if let state { a["state"] = state }
        if let start { a["timestamps"] = ["start": Int(start.timeIntervalSince1970)] }
        if let image {
            var assets: [String: Any] = ["large_image": image]
            if let imageText { assets["large_text"] = imageText }
            if let smallImage { assets["small_image"] = smallImage }
            if let smallText { assets["small_text"] = smallText }
            a["assets"] = assets
        }
        return a
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let clientID = "1564590186887774209"
    private static let enabledKey = "presenceEnabled"
    /// Rich Presence art asset key, uploaded in the Discord developer portal.
    private static let astrisLogo = "astris"

    private let detector = GameDetector()
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
    private var discordConnected = false
    private var timer: Timer?

    private var enabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGPIPE, SIG_IGN)
        setUpMenu()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.tick() }
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
                presence = Presence(
                    details: game.name,
                    state: "Sur Astris",
                    start: game.start,
                    image: game.titleID.map { "https://tinfoil.media/ti/\($0)/512/512" } ?? Self.astrisLogo,
                    imageText: game.name)
            } else {
                presence = Presence(
                    details: "Dans le menu", state: "Sur Astris", start: astris.launchDate,
                    image: Self.astrisLogo, imageText: "Astris")
            }
        }

        push(presence)
        refreshMenu(astrisRunning: astris != nil)
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
}
