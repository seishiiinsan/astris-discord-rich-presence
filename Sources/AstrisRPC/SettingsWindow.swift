import AppKit
import Charts
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// Native macOS Settings window: toolbar tabs (General, Games), opened with ⌘,.
final class SettingsWindowController: NSWindowController {
    convenience init(settings: GameSettings, covers: CoverResolver, recents: RecentGames, history: PlayHistory) {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar

        let general = NSHostingController(rootView: GeneralSettingsView(settings: settings, recents: recents))
        let discord = NSHostingController(rootView: DiscordSettingsView(settings: settings))
        let games = NSHostingController(rootView: GamesSettingsView(settings: settings, covers: covers, recents: recents))
        let stats = NSHostingController(rootView: StatsView(history: history, settings: settings, covers: covers))
        let tools = NSHostingController(rootView: ToolsView(settings: settings, history: history))
        tools.sizingOptions = .preferredContentSize
        tools.title = L10n.tr("Outils", "Tools")
        general.sizingOptions = .preferredContentSize
        discord.sizingOptions = .preferredContentSize
        games.sizingOptions = .preferredContentSize
        stats.sizingOptions = .preferredContentSize

        // The window title follows the selected tab.
        general.title = L10n.tr("Général", "General")
        discord.title = "Discord"
        games.title = L10n.tr("Jeux", "Games")
        stats.title = L10n.tr("Statistiques", "Stats")

        let generalItem = NSTabViewItem(viewController: general)
        generalItem.label = L10n.tr("Général", "General")
        generalItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        let discordItem = NSTabViewItem(viewController: discord)
        discordItem.label = "Discord"
        discordItem.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: nil)
        let gamesItem = NSTabViewItem(viewController: games)
        gamesItem.label = L10n.tr("Jeux", "Games")
        gamesItem.image = NSImage(systemSymbolName: "gamecontroller", accessibilityDescription: nil)
        tabs.addTabViewItem(generalItem)
        tabs.addTabViewItem(discordItem)
        tabs.addTabViewItem(gamesItem)
        let statsItem = NSTabViewItem(viewController: stats)
        statsItem.label = L10n.tr("Statistiques", "Stats")
        statsItem.image = NSImage(systemSymbolName: "chart.bar", accessibilityDescription: nil)
        tabs.addTabViewItem(statsItem)
        let toolsItem = NSTabViewItem(viewController: tools)
        toolsItem.label = L10n.tr("Outils", "Tools")
        toolsItem.image = NSImage(systemSymbolName: "wrench.and.screwdriver", accessibilityDescription: nil)
        tabs.addTabViewItem(toolsItem)

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func show(tab: Int? = nil) {
        if let tab, let tabs = window?.contentViewController as? NSTabViewController {
            tabs.selectedTabViewItemIndex = tab
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Layout

enum SettingsLayout {
    /// Tabs share one height that fits the screen (menu bar, Dock and title bar aside): long tabs scroll.
    static var height: CGFloat {
        let visible = NSScreen.main?.visibleFrame.height ?? 800
        return max(360, min(560, visible - 120))
    }
}

// MARK: - Relaunch

enum Relauncher {
    /// Starts a fresh copy once this one has quit.
    static func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "while kill -0 \(getpid()) 2>/dev/null; do sleep 0.2; done; open \"\(Bundle.main.bundlePath)\""]
        try? task.run()
        NSApp.terminate(nil)
    }
}

// MARK: - Folder picking

enum FolderPicker {
    static func pick(startingAt url: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = url
        panel.prompt = L10n.tr("Choisir", "Choose")
        panel.message = L10n.tr("Choisis le dossier où tu ranges tes jeux Switch.", "Choose the folder where you keep your Switch games.")
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Astris' own games folder, else the folder of the last game seen running.
    static func suggestion(from recents: RecentGames) -> URL? {
        AstrisConfig.load()?.existingGameDirectories.first
            ?? recents.entries.first.map { URL(fileURLWithPath: $0.romPath).deletingLastPathComponent() }
    }

    static func abbreviated(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @ObservedObject var settings: GameSettings
    let recents: RecentGames
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle(L10n.tr("Afficher mon jeu sur Discord", "Show my game on Discord"), isOn: $settings.showOnDiscord)
                Toggle(L10n.tr("Ouvrir à la connexion", "Open at Login"), isOn: Binding(
                    get: { openAtLogin },
                    set: setOpenAtLogin))
                Toggle(L10n.tr("Chrono de session dans la barre des menus", "Session timer in the menu bar"), isOn: $settings.menuBarTimer)
                Toggle(isOn: $settings.hotKeysEnabled) {
                    Text(L10n.tr("Raccourcis clavier globaux", "Global keyboard shortcuts"))
                    Text(L10n.tr("⌃⌥⌘D afficher sur Discord · ⌃⌥⌘H masquer le jeu en cours · ⌃⌥⌘G lancer un jeu",
                                 "⌃⌥⌘D show on Discord · ⌃⌥⌘H hide the current game · ⌃⌥⌘G open a game"))
                }
                Picker(L10n.tr("Afficher « En pause » après", "Show “Idle” after"), selection: $settings.idleMinutes) {
                    ForEach(GameSettings.idleChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? L10n.tr("Jamais", "Never") : "\(minutes) min").tag(minutes)
                    }
                }
                Picker(L10n.tr("Langue", "Language"), selection: $settings.language) {
                    Text(L10n.tr("Comme le Mac", "Same as the Mac")).tag(L10n.Language.system)
                    Text("Français").tag(L10n.Language.french)
                    Text("English").tag(L10n.Language.english)
                }
                if L10n.resolve(settings.language, preferred: Locale.preferredLanguages) != L10n.isFrench {
                    HStack {
                        Text(L10n.tr("Appliquée au prochain lancement.", "Applies at next launch."))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L10n.tr("Relancer", "Relaunch"), action: Relauncher.relaunch)
                    }
                }
            } footer: {
                Text(L10n.tr(
                    "Tes amis voient le jeu, sa jaquette et ton temps de jeu. Sans clavier, souris ni manette pendant le délai choisi, Discord affiche « En pause ».",
                    "Friends see the game, its cover art and your play time. With no keyboard, mouse or controller input for the chosen delay, Discord shows “Idle”."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                LabeledContent(L10n.tr("Dossier des jeux", "Games folder")) {
                    HStack(spacing: 8) {
                        Text(settings.gamesFolder.map(FolderPicker.abbreviated) ?? L10n.tr("Aucun", "None"))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(settings.gamesFolder?.path ?? "")
                        Button(L10n.tr("Choisir…", "Choose…")) {
                            if let url = FolderPicker.pick(startingAt: settings.gamesFolder ?? FolderPicker.suggestion(from: recents)) {
                                settings.gamesFolder = url
                            }
                        }
                    }
                }
                if let folder = settings.gamesFolder {
                    Button(L10n.tr("Afficher dans le Finder", "Show in Finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([folder])
                    }
                }
            } header: {
                Text(L10n.tr("Jeux", "Games"))
            } footer: {
                Text(L10n.tr(
                    "Les jeux de ce dossier apparaissent dans l'onglet Jeux.",
                    "Games in this folder appear in the Games tab."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Toggle(L10n.tr("Discord déconnecté en jeu", "Discord disconnected while playing"), isOn: $settings.notifyDiscordLost)
                Toggle(L10n.tr("Mise à jour disponible", "Update available"), isOn: $settings.notifyUpdates)
                Toggle(L10n.tr("Bilan de la semaine (dimanche soir)", "Weekly summary (Sunday evening)"), isOn: $settings.notifyWeeklySummary)
                Toggle(L10n.tr("Paliers (10, 25, 50, 100 h…) et records de session", "Milestones (10, 25, 50, 100 h…) and session records"), isOn: $settings.notifyMilestones)
                Toggle(L10n.tr("Batterie de manette faible (20 %)", "Low controller battery (20%)"), isOn: $settings.notifyLowBattery)
                Picker(L10n.tr("Rappel de pause", "Break reminder"), selection: $settings.breakReminderMinutes) {
                    ForEach(PlayReminders.breakChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? L10n.tr("Jamais", "Never") : PlayHistory.format(TimeInterval(minutes * 60))).tag(minutes)
                    }
                }
            } header: {
                Text("Notifications")
            }

            Section {
                Toggle(L10n.tr("Enregistrer un journal", "Keep a log file"), isOn: $settings.writeLog)
                HStack {
                    Button(L10n.tr("Afficher le journal", "Show Log")) {
                        NSWorkspace.shared.activateFileViewerSelecting([Log.file])
                    }
                    .disabled(!FileManager.default.fileExists(atPath: Log.file.path))
                    Button(L10n.tr("Vider le cache des jaquettes", "Clear Cover Cache")) {
                        ImageCache.shared.clear()
                    }
                }
            } header: {
                Text(L10n.tr("Dépannage", "Troubleshooting"))
            } footer: {
                Text(L10n.tr(
                    "Le journal est écrit dans ~/Library/Logs/AstrisRPC.log. Menu → Copier le diagnostic pour signaler un problème.",
                    "The log goes to ~/Library/Logs/AstrisRPC.log. Menu → Copy Diagnostics to report a problem."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: SettingsLayout.height)
        .onAppear { openAtLogin = SMAppService.mainApp.status == .enabled }
    }

    private func setOpenAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSAlert(error: error).runModal()
        }
        openAtLogin = SMAppService.mainApp.status == .enabled
    }
}

// MARK: - Discord

struct DiscordSettingsView: View {
    @ObservedObject var settings: GameSettings

    var body: some View {
        Form {
            Section {
                TextField(L10n.tr("Ligne 1", "Line 1"), text: optional(\.detailsTemplate), prompt: Text(PresenceTemplate.defaultDetails))
                TextField(L10n.tr("Ligne 2", "Line 2"), text: optional(\.stateTemplate), prompt: Text(PresenceTemplate.defaultState))
            } header: {
                Text(L10n.tr("Texte", "Text"))
            } footer: {
                Text(L10n.tr(
                    "Variables : {game} nom du jeu, {played} temps déjà joué, {version} version, {mode} mode TV ou portable, {multi} « Multijoueur local » si actif dans Astris, {status} statut du jeu (En cours…). Une partie « · » dont la variable est inconnue est retirée. Vide : texte par défaut.",
                    "Variables: {game} game name, {played} time already played, {version} version, {mode} TV or handheld mode, {multi} “Local multiplayer” when on in Astris, {status} game status (Playing…). A “ · ” part whose variable is unknown is left out. Empty: default text."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Toggle(L10n.tr("Mode streamer", "Streamer mode"), isOn: $settings.streamerMode)
                Group {
                    Toggle(L10n.tr("Cacher le temps joué", "Hide play time"), isOn: $settings.streamerHidesPlayed)
                    Toggle(L10n.tr("Cacher le bouton eShop", "Hide the eShop button"), isOn: $settings.streamerHidesEShop)
                    Toggle(L10n.tr("Cacher les jaquettes", "Hide covers"), isOn: $settings.streamerHidesCover)
                }
                .disabled(!settings.streamerMode)
                .padding(.leading, 16)
            } footer: {
                Text(L10n.tr(
                    "Aussi dans le menu. Pour cacher un jeu entier : onglet Jeux.",
                    "Also in the menu. To hide a whole game: Games tab."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                SecureField(L10n.tr("Clé API", "API key"), text: Binding(
                    get: { settings.steamGridDBKey ?? "" },
                    set: { settings.steamGridDBKey = $0.isEmpty ? nil : $0 }))
                Toggle(L10n.tr("Préférer SteamGridDB", "Prefer SteamGridDB"), isOn: $settings.preferSteamGridDB)
                    .disabled(settings.steamGridDBKey == nil)
            } header: {
                Text("SteamGridDB")
            } footer: {
                Text(L10n.tr(
                    "Jaquettes en plus, cherchées par nom : homebrew et jeux sans TitleID compris. Clé gratuite sur steamgriddb.com → Préférences → API.",
                    "Extra covers, found by name: homebrew and games without a TitleID included. Free key at steamgriddb.com → Preferences → API."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Toggle(L10n.tr("Bouton « Voir sur l'eShop »", "“View on eShop” button"), isOn: $settings.showEShopButton)
                TextField(L10n.tr("Libellé", "Label"), text: optional(\.customButtonLabel), prompt: Text("Astris"))
                TextField("URL", text: optional(\.customButtonURL), prompt: Text("https://…"))
                if settings.customButtonLabel != nil || settings.customButtonURL != nil, settings.customButton == nil {
                    Label(L10n.tr("Il faut un libellé et une adresse https://", "Needs a label and an https:// address"),
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text(L10n.tr("Boutons", "Buttons"))
            } footer: {
                Text(L10n.tr(
                    "Le second bouton mène à Astris, ou à ton lien s'il est rempli. Discord n'affiche pas les boutons sur ton propre profil, seulement aux autres.",
                    "The second button links to Astris, or to your link when set. Discord hides buttons on your own profile, others see them."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: SettingsLayout.height)
    }

    private func optional(_ key: ReferenceWritableKeyPath<GameSettings, String?>) -> Binding<String> {
        Binding(
            get: { settings[keyPath: key] ?? "" },
            set: { settings[keyPath: key] = $0.isEmpty ? nil : $0 })
    }
}

// MARK: - Games

struct GamesSettingsView: View {
    @ObservedObject var settings: GameSettings
    let covers: CoverResolver
    let recents: RecentGames

    @State private var games: [GameLibrary.Game] = []
    @State private var selection: GameLibrary.Game.ID?
    @State private var search = ""
    @State private var filter = Filter.all
    @State private var bySize = false
    @State private var duplicates: Set<GameLibrary.Game.ID> = []

    enum Filter: Hashable {
        case all, favorites, status(PlayStatus)
    }

    private var filtered: [GameLibrary.Game] {
        var list = games.filter { game in
            switch filter {
            case .all: return true
            case .favorites: return settings.isFavorite(game.url.path)
            case .status(let status): return settings.prefs(for: game.url.path).status == status
            }
        }
        if !search.isEmpty {
            list = list.filter {
                settings.displayName(for: $0.url.path, detected: $0.name).localizedCaseInsensitiveContains(search)
            }
        }
        return bySize ? list.sorted { $0.size > $1.size } : list
    }

    var body: some View {
        Group {
            if settings.gamesFolder == nil {
                noFolder
            } else if games.isEmpty {
                EmptyStateView(
                    symbol: "magnifyingglass",
                    title: L10n.tr("Aucun jeu trouvé", "No games found"),
                    message: L10n.tr(
                        "Aucun fichier .xci, .xcz, .nsp, .nsz ou .nro dans ce dossier.",
                        "No .xci, .xcz, .nsp, .nsz or .nro files in this folder.")) {
                    Button(L10n.tr("Choisir un autre dossier…", "Choose Another Folder…"), action: pickFolder)
                }
            } else {
                HStack(spacing: 0) {
                    sidebar.frame(width: 250)
                    Divider()
                    detail.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 700, height: SettingsLayout.height)
        .onAppear(perform: reload)
        .onChange(of: settings.gamesFolder) { _ in reload() }
    }

    private var noFolder: some View {
        EmptyStateView(
            symbol: "folder.badge.questionmark",
            title: L10n.tr("Aucun dossier de jeux", "No games folder"),
            message: L10n.tr(
                "Choisis le dossier où tu ranges tes jeux pour régler leur affichage sur Discord.",
                "Choose the folder where you keep your games to control how they appear on Discord.")) {
            if let suggestion = FolderPicker.suggestion(from: recents) {
                Button(L10n.tr("Utiliser « \(suggestion.lastPathComponent) »", "Use “\(suggestion.lastPathComponent)”")) {
                    settings.gamesFolder = suggestion
                }
                .buttonStyle(.borderedProminent)
            }
            Button(L10n.tr("Choisir un dossier…", "Choose a Folder…"), action: pickFolder)
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            TextField(L10n.tr("Rechercher", "Search"), text: $search)
                .textFieldStyle(.roundedBorder)
                .padding([.horizontal, .top], 10)
            HStack {
                Picker(L10n.tr("Afficher", "Show"), selection: $filter) {
                    Text(L10n.tr("Tous", "All")).tag(Filter.all)
                    Text(L10n.tr("Favoris", "Favorites")).tag(Filter.favorites)
                    Divider()
                    ForEach(PlayStatus.allCases, id: \.self) { status in
                        Label(status.label, systemImage: status.symbol).tag(Filter.status(status))
                    }
                }
                .labelsHidden()
                Picker(L10n.tr("Tri", "Sort"), selection: $bySize) {
                    Text(L10n.tr("Nom", "Name")).tag(false)
                    Text(L10n.tr("Taille", "Size")).tag(true)
                }
                .labelsHidden()
                .fixedSize()
            }
            .padding(10)
            List(filtered, selection: $selection) { game in
                GameRow(game: game, settings: settings, covers: covers, duplicate: duplicates.contains(game.id)).tag(game.id)
            }
            .listStyle(.sidebar)
            // Double-click launches; right-click for the rest.
            .contextMenu(forSelectionType: GameLibrary.Game.ID.self) { ids in
                if let path = ids.first {
                    Button(L10n.tr("Lancer dans Astris", "Open in Astris")) { AstrisLauncher.open(path) }
                    Button(settings.isFavorite(path) ? L10n.tr("Retirer des favoris", "Remove from Favorites") : L10n.tr("Ajouter aux favoris", "Add to Favorites")) {
                        settings.setFavorite(!settings.isFavorite(path), for: path)
                    }
                    Divider()
                    Button(L10n.tr("Afficher dans le Finder", "Show in Finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }
                }
            } primaryAction: { ids in
                if let path = ids.first { AstrisLauncher.open(path) }
            }
            Divider()
            Text(L10n.tr(
                "\(games.count) jeux · \(GameLibrary.formatSize(totalSize)) · \(hiddenCount) masqués" + (duplicates.isEmpty ? "" : " · \(duplicates.count) doublons"),
                "\(games.count) games · \(GameLibrary.formatSize(totalSize)) · \(hiddenCount) hidden" + (duplicates.isEmpty ? "" : " · \(duplicates.count) duplicates")))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
        }
    }

    private var totalSize: Int64 {
        games.reduce(0) { $0 + $1.size }
    }

    private var hiddenCount: Int {
        games.filter { settings.isHidden($0.url.path) }.count
    }

    @ViewBuilder
    private var detail: some View {
        if let game = games.first(where: { $0.id == selection }) {
            GameDetailView(game: game, settings: settings, covers: covers)
                .id(game.id)
        } else {
            EmptyStateView(
                symbol: "gamecontroller",
                title: L10n.tr("Sélectionne un jeu", "Select a game"),
                message: L10n.tr(
                    "Choisis s'il apparaît sur Discord et sous quel nom.",
                    "Choose whether it appears on Discord, and under which name.")) { EmptyView() }
        }
    }

    private func reload() {
        guard let folder = settings.gamesFolder else { games = []; return }
        var known = settings.knownTitleIDs
        for entry in recents.entries {
            if let id = entry.titleID { known[(entry.romPath as NSString).lastPathComponent] = id }
        }
        games = GameLibrary.scan(folder, known: known, titles: GameDetector.metadataTitleIndex())
        duplicates = GameLibrary.duplicates(games)
        if selection == nil || !games.contains(where: { $0.id == selection }) {
            selection = games.first?.id
        }
    }

    private func pickFolder() {
        if let url = FolderPicker.pick(startingAt: settings.gamesFolder ?? FolderPicker.suggestion(from: recents)) {
            settings.gamesFolder = url
        }
    }
}

private struct GameRow: View {
    let game: GameLibrary.Game
    @ObservedObject var settings: GameSettings
    let covers: CoverResolver
    var duplicate = false

    var body: some View {
        let hidden = settings.isHidden(game.url.path)
        HStack(spacing: 10) {
            CoverView(titleID: game.titleID, covers: covers, size: 32, customCover: settings.prefs(for: game.url.path).customCover, name: game.name, settings: settings)
                .opacity(hidden ? 0.45 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.displayName(for: game.url.path, detected: game.name))
                    .lineLimit(1)
                    .foregroundStyle(hidden ? .secondary : .primary)
                let caption = [
                    hidden ? L10n.tr("Masqué sur Discord", "Hidden on Discord") : nil,
                    settings.prefs(for: game.url.path).status?.label,
                    duplicate ? L10n.tr("Doublon", "Duplicate") : nil,
                ].compactMap { $0 }.joined(separator: " · ")
                if !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(duplicate ? .orange : .secondary)
                }
            }
            Spacer(minLength: 0)
            if settings.isFavorite(game.url.path) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel(L10n.tr("Favori", "Favorite"))
            }
            if hidden {
                Image(systemName: "eye.slash")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(L10n.tr("Masqué", "Hidden"))
            }
        }
        .padding(.vertical, 2)
    }
}

private struct GameDetailView: View {
    let game: GameLibrary.Game
    @ObservedObject var settings: GameSettings
    let covers: CoverResolver
    @State private var name = ""
    @State private var coverLink = ""
    @State private var details = ""
    @State private var note = ""
    @State private var state = ""

    private var path: String { game.url.path }

    static func kindLabel(_ titleID: String) -> String? {
        switch GameDetector.kind(of: titleID) {
        case .base: return L10n.tr("Jeu de base", "Base game")
        case .update: return L10n.tr("Mise à jour", "Update")
        case .dlc: return "DLC"
        case nil: return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                CoverView(titleID: game.titleID, covers: covers, size: 112, customCover: settings.prefs(for: path).customCover, name: game.name, settings: settings)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .dropDestination(for: URL.self) { urls, _ in
                        guard let url = urls.first else { return false }
                        useCover(url)
                        return true
                    }
                    .help(L10n.tr("Glisse une image ici pour changer la jaquette", "Drop an image here to change the cover"))
                Text(settings.displayName(for: path, detected: game.name))
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(game.url.lastPathComponent + " · " + GameLibrary.formatSize(game.size))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let id = game.titleID {
                    Text([Self.kindLabel(id), id, GameDetector.version(in: game.url.deletingPathExtension().lastPathComponent)]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)

            Form {
                Section {
                    Picker(L10n.tr("Statut", "Status"), selection: Binding(
                        get: { settings.prefs(for: path).status },
                        set: { settings.setStatus($0, for: path) })) {
                        Text(L10n.tr("Aucun", "None")).tag(PlayStatus?.none)
                        ForEach(PlayStatus.allCases, id: \.self) { status in
                            Label(status.label, systemImage: status.symbol).tag(PlayStatus?.some(status))
                        }
                    }
                    LabeledContent(L10n.tr("Note", "Rating")) {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    let current = settings.prefs(for: path).rating
                                    settings.setRating(current == star ? nil : star, for: path)
                                } label: {
                                    Image(systemName: (settings.prefs(for: path).rating ?? 0) >= star ? "star.fill" : "star")
                                        .foregroundStyle(.yellow)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(star)")
                            }
                        }
                    }
                    TextField(L10n.tr("Mémo", "Memo"), text: $note, prompt: Text(L10n.tr("Où j'en suis, à faire…", "Where I'm at, to do…")), axis: .vertical)
                        .lineLimit(1...4)
                        .onChange(of: note) { settings.setNote($0, for: path) }
                } header: {
                    Text(L10n.tr("Suivi", "Tracking"))
                }
                Section {
                    Toggle(L10n.tr("Afficher sur Discord", "Show on Discord"), isOn: Binding(
                        get: { !settings.isHidden(path) },
                        set: { settings.setHidden(!$0, for: path) }))
                    Toggle(L10n.tr("Cacher le temps joué", "Hide play time"), isOn: Binding(
                        get: { settings.prefs(for: path).hidePlayedTime },
                        set: { settings.setHidePlayedTime($0, for: path) }))
                        .disabled(settings.isHidden(path))
                } footer: {
                    Text(settings.isHidden(path)
                         ? L10n.tr("Discord affichera seulement « En jeu · Sur Astris », sans nom ni jaquette.",
                                   "Discord will only show “Playing · On Astris”, with no name or cover.")
                         : L10n.tr("Discord affiche le nom, la jaquette et le temps de jeu.",
                                   "Discord shows the name, cover and play time."))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Section {
                    HStack {
                        TextField(L10n.tr("Jaquette", "Cover"), text: $coverLink, prompt: Text("https://…"))
                            .onSubmit { settings.setCustomCover(coverLink, for: path) }
                        Button(L10n.tr("Choisir…", "Choose…"), action: pickCover)
                        if settings.prefs(for: path).customCover != nil {
                            Button(L10n.tr("Par défaut", "Default")) {
                                settings.setCustomCover(nil, for: path)
                                coverLink = ""
                            }
                        }
                    }
                } footer: {
                    Text(isLocalCover
                         ? L10n.tr("Image locale : visible ici seulement. Discord n'affiche que des images en ligne (https).",
                                   "Local image: shown here only. Discord only shows online images (https).")
                         : L10n.tr("Adresse d'une image en ligne, ou glisse une image sur la jaquette.",
                                   "Address of an online image, or drop an image on the cover."))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Section {
                    TextField(L10n.tr("Ligne 1", "Line 1"), text: $details, prompt: Text(settings.detailsTemplate ?? PresenceTemplate.defaultDetails))
                        .onChange(of: details) { _ in saveTemplates() }
                    TextField(L10n.tr("Ligne 2", "Line 2"), text: $state, prompt: Text(settings.stateTemplate ?? PresenceTemplate.defaultState))
                        .onChange(of: state) { _ in saveTemplates() }
                } header: {
                    Text(L10n.tr("Texte pour ce jeu", "Text for this game"))
                } footer: {
                    Text(L10n.tr("Vide : texte de l'onglet Discord.", "Empty: text from the Discord tab."))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(settings.isHidden(path))
                Section {
                    TextField(L10n.tr("Nom affiché", "Display name"), text: $name, prompt: Text(game.name))
                        .onSubmit { settings.setCustomName(name, for: path) }
                        .onChange(of: name) { settings.setCustomName($0, for: path) }
                        .disabled(settings.isHidden(path))
                } footer: {
                    Text(L10n.tr("Laisse vide pour garder le nom détecté.", "Leave empty to keep the detected name."))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button(L10n.tr("Afficher dans le Finder", "Show in Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([game.url])
                }
                Toggle(isOn: Binding(
                    get: { settings.isFavorite(path) },
                    set: { settings.setFavorite($0, for: path) })) {
                    Label(L10n.tr("Favori", "Favorite"), systemImage: settings.isFavorite(path) ? "star.fill" : "star")
                }
                .toggleStyle(.button)
                Spacer()
                Button(L10n.tr("Lancer dans Astris", "Open in Astris")) { AstrisLauncher.open(path) }
                    .buttonStyle(.borderedProminent)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .onAppear {
            name = settings.prefs(for: path).customName ?? ""
            details = settings.prefs(for: path).detailsTemplate ?? ""
            note = settings.prefs(for: path).note ?? ""
            state = settings.prefs(for: path).stateTemplate ?? ""
            let cover = settings.prefs(for: path).customCover
            coverLink = cover.flatMap { URL(string: $0)?.isFileURL == true ? nil : $0 } ?? ""
        }
    }

    private func saveTemplates() {
        settings.setTemplates(details: details, state: state, for: path)
    }

    private var isLocalCover: Bool {
        settings.prefs(for: path).customCover.flatMap { URL(string: $0)?.isFileURL } ?? false
    }

    private func pickCover() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { useCover(url) }
    }

    private func useCover(_ url: URL) {
        if url.isFileURL {
            do {
                try settings.importCover(from: url, for: path)
                coverLink = ""
            } catch {
                NSAlert(error: error).runModal()
            }
        } else {
            settings.setCustomCover(url.absoluteString, for: path)
            coverLink = url.absoluteString
        }
    }
}

// MARK: - Tools

struct ToolsView: View {
    @ObservedObject var settings: GameSettings
    let history: PlayHistory
    @State private var backups: [URL] = []
    @State private var status: String?
    @State private var working = false
    @State private var restoreTarget: URL?
    @State private var confirmImport: URL?

    var body: some View {
        Form {
            Section {
                Toggle(L10n.tr("Notification à chaque capture", "Notify on each screenshot"), isOn: $settings.notifyScreenshots)
                Toggle(L10n.tr("Copier la capture dans le presse-papiers", "Copy the screenshot to the clipboard"), isOn: $settings.copyScreenshots)
                Button(L10n.tr("Ouvrir le dossier des captures", "Open Screenshots Folder")) {
                    if let dir = AstrisFiles.screenshotDirectories.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
                        NSWorkspace.shared.open(dir)
                    } else {
                        NSSound.beep()
                    }
                }
            } header: {
                Text(L10n.tr("Captures d'écran", "Screenshots"))
            } footer: {
                footnote(L10n.tr("Les captures faites dans Astris. La dernière est aussi dans le menu.",
                                 "Screenshots taken in Astris. The latest one is also in the menu."))
            }

            Section {
                Picker(L10n.tr("Sauvegarde automatique", "Automatic backup"), selection: $settings.autoBackup) {
                    Text(L10n.tr("Jamais", "Never")).tag(GameSettings.AutoBackup.off)
                    Text(L10n.tr("À la fermeture d'un jeu", "When a game closes")).tag(GameSettings.AutoBackup.gameClosed)
                    Text(L10n.tr("Chaque semaine", "Weekly")).tag(GameSettings.AutoBackup.weekly)
                }
                HStack {
                    Button(L10n.tr("Sauvegarder maintenant", "Back Up Now"), action: backUp)
                        .disabled(working || AstrisFiles.saveDirectory == nil)
                    Button(L10n.tr("Afficher les sauvegardes", "Show Backups")) {
                        try? FileManager.default.createDirectory(at: AstrisFiles.backupDirectory, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(AstrisFiles.backupDirectory)
                    }
                    if working { ProgressView().controlSize(.small) }
                }
                ForEach(backups.prefix(5), id: \.self) { archive in
                    HStack {
                        Text(archive.deletingPathExtension().lastPathComponent).lineLimit(1)
                        Spacer()
                        Button(L10n.tr("Restaurer…", "Restore…")) { restoreTarget = archive }
                            .disabled(working)
                    }
                }
                if let status {
                    Text(status).foregroundStyle(.secondary)
                }
            } header: {
                Text(L10n.tr("Sauvegardes des jeux", "Game saves"))
            } footer: {
                footnote(AstrisFiles.saveDirectory == nil
                         ? L10n.tr("Dossier des saves d'Astris introuvable.", "Astris' save folder not found.")
                         : L10n.tr("Zip des saves d'Astris dans ~/Documents/Astris RPC. Les \(AstrisFiles.keptBackups) dernières sont gardées.",
                                   "Zip of Astris' saves in ~/Documents/Astris RPC. The last \(AstrisFiles.keptBackups) are kept."))
            }

            Section {
                HStack {
                    Button(L10n.tr("Exporter les réglages…", "Export Settings…"), action: exportSettings)
                    Button(L10n.tr("Importer…", "Import…"), action: pickImport)
                }
            } header: {
                Text(L10n.tr("Réglages", "Settings"))
            } footer: {
                footnote(L10n.tr("Un fichier avec tous les réglages, les réglages par jeu, les favoris et l'historique de jeu. Pour changer de Mac.",
                                 "One file with every setting, per-game settings, favorites and play history. To move to another Mac."))
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: SettingsLayout.height)
        .onAppear(perform: reloadBackups)
        .confirmationDialog(L10n.tr("Restaurer cette sauvegarde ?", "Restore this backup?"),
                            isPresented: Binding(get: { restoreTarget != nil }, set: { if !$0 { restoreTarget = nil } })) {
            Button(L10n.tr("Restaurer", "Restore"), role: .destructive) { if let restoreTarget { restore(restoreTarget) } }
        } message: {
            Text(L10n.tr("Astris doit être fermé. Les saves actuelles sont gardées à côté (« save before restore … »).",
                         "Astris must be closed. Current saves are kept aside (“save before restore …”)."))
        }
        .confirmationDialog(L10n.tr("Remplacer tous les réglages ?", "Replace all settings?"),
                            isPresented: Binding(get: { confirmImport != nil }, set: { if !$0 { confirmImport = nil } })) {
            Button(L10n.tr("Importer et relancer", "Import and Relaunch"), role: .destructive) { if let confirmImport { importSettings(confirmImport) } }
        } message: {
            Text(L10n.tr("Les réglages et l'historique de ce Mac seront remplacés.", "This Mac's settings and history will be replaced."))
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reloadBackups() {
        backups = AstrisFiles.backups()
    }

    private func backUp() {
        working = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try AstrisFiles.backUpSaves() }
            DispatchQueue.main.async {
                working = false
                switch result {
                case .success(let archive): status = L10n.tr("Sauvegardé : \(archive.lastPathComponent)", "Saved: \(archive.lastPathComponent)")
                case .failure(let error): status = error.localizedDescription
                }
                reloadBackups()
            }
        }
    }

    private func restore(_ archive: URL) {
        let astrisOpen = NSWorkspace.shared.runningApplications.contains { $0.localizedName?.lowercased() == "astris" }
        guard !astrisOpen else {
            status = L10n.tr("Ferme Astris avant de restaurer.", "Quit Astris before restoring.")
            return
        }
        guard let saves = AstrisFiles.saveDirectory ?? AstrisFiles.baseDirectories.first?.appendingPathComponent("bis/user/save") else { return }
        working = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try AstrisFiles.restore(archive, into: saves) }
            DispatchQueue.main.async {
                working = false
                switch result {
                case .success: status = L10n.tr("Restauré : \(archive.lastPathComponent)", "Restored: \(archive.lastPathComponent)")
                case .failure(let error): status = error.localizedDescription
                }
                Log.shared.add("Restore \(archive.lastPathComponent): \(status ?? "")")
            }
        }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Astris RPC.\(SettingsTransfer.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try SettingsTransfer.export(to: url, history: history)
            status = nil
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func pickImport() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { confirmImport = url }
    }

    private func importSettings(_ url: URL) {
        do {
            _ = try SettingsTransfer.decode(Data(contentsOf: url))
            history.savingEnabled = false
            try SettingsTransfer.importFile(url)
            Relauncher.relaunch()
        } catch {
            history.savingEnabled = true
            NSAlert(error: error).runModal()
        }
    }
}

// MARK: - Stats

struct StatsView: View {
    @ObservedObject var history: PlayHistory
    @ObservedObject var settings: GameSettings
    let covers: CoverResolver
    @State private var confirmClear = false
    @State private var range = ChartRange.days
    @State private var order = Order.mostPlayed
    /// TitleID → time Astris counted, read when the tab opens.
    @State private var astrisPlayed: [String: TimeInterval] = [:]

    enum ChartRange: Hashable { case days, weeks }
    enum Order: Hashable { case mostPlayed, recent }

    var body: some View {
        let week = PlayHistory.startOfWeek()
        let rows = sorted(history.totals(recentSince: week))
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                StatTile(value: PlayHistory.format(history.total(since: week)), label: L10n.tr("Cette semaine", "This week"))
                Divider().frame(height: 40)
                StatTile(value: PlayHistory.format(history.total(since: .distantPast)), label: L10n.tr("Au total", "In total"))
                Divider().frame(height: 40)
                StatTile(value: "\(rows.count)", label: L10n.tr("Jeux lancés", "Games played"))
            }
            .padding(.vertical, 12)
            Divider()
            if rows.isEmpty {
                EmptyStateView(
                    symbol: "chart.bar",
                    title: L10n.tr("Aucune session pour l'instant", "No sessions yet"),
                    message: L10n.tr(
                        "Le temps passé en jeu sur Astris est compté ici à partir de maintenant, sans les pauses.",
                        "Time in game on Astris is counted here from now on, without idle time.")) { EmptyView() }
            } else {
                chart.padding(12)
                Divider()
                list(rows)
            }
            Divider()
            HStack {
                Picker(L10n.tr("Tri", "Sort"), selection: $order) {
                    Text(L10n.tr("Plus joué", "Most played")).tag(Order.mostPlayed)
                    Text(L10n.tr("Plus récent", "Most recent")).tag(Order.recent)
                }
                .fixedSize()
                .disabled(rows.isEmpty)
                Spacer()
                Button(L10n.tr("Exporter en CSV…", "Export as CSV…"), action: export)
                    .disabled(rows.isEmpty)
                Button(L10n.tr("Effacer l'historique…", "Clear History…")) { confirmClear = true }
                    .disabled(rows.isEmpty)
            }
            .padding(10)
        }
        .frame(width: 700, height: SettingsLayout.height)
        .confirmationDialog(L10n.tr("Effacer tout l'historique de jeu ?", "Clear all play history?"), isPresented: $confirmClear) {
            Button(L10n.tr("Effacer", "Clear"), role: .destructive) { history.clear() }
        }
        .task {
            let info = await Task.detached { GameDetector.astrisGameInfo() }.value
            astrisPlayed = info.compactMapValues(\.played)
        }
    }

    private var chart: some View {
        let buckets = range == .days
            ? history.totals(in: PlayHistory.days(7))
            : history.totals(in: PlayHistory.weeks(4))
        return VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $range) {
                Text(L10n.tr("7 jours", "7 days")).tag(ChartRange.days)
                Text(L10n.tr("4 semaines", "4 weeks")).tag(ChartRange.weeks)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Chart(buckets) { bucket in
                BarMark(
                    x: .value(L10n.tr("Période", "Period"), bucket.start, unit: range == .days ? .day : .weekOfYear),
                    y: .value(L10n.tr("Heures", "Hours"), bucket.seconds / 3600))
                    .foregroundStyle(Color.accentColor)
            }
            .chartYAxisLabel(L10n.tr("heures", "hours"))
            .frame(height: 110)
            .accessibilityLabel(L10n.tr("Temps de jeu par période", "Play time per period"))
        }
    }

    private func list(_ rows: [PlayHistory.GameTotal]) -> some View {
        List(rows) { row in
            HStack(spacing: 10) {
                CoverView(titleID: row.titleID, covers: covers, size: 32, customCover: settings.prefs(for: row.rom).customCover, name: row.name, settings: settings)
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.displayName(for: row.rom, detected: row.name)).lineLimit(1)
                    Text(row.lastPlayed.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(PlayHistory.format(row.total)).monospacedDigit()
                    Text(detail(row))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
        .listStyle(.inset)
    }

    /// "2 h 05 cette semaine · Astris : 120 h 00"
    private func detail(_ row: PlayHistory.GameTotal) -> String {
        var parts: [String] = []
        if row.recent > 0 { parts.append(L10n.tr("\(PlayHistory.format(row.recent)) cette semaine", "\(PlayHistory.format(row.recent)) this week")) }
        if let id = row.titleID, let astris = astrisPlayed[id], astris >= 60 {
            parts.append("Astris : \(PlayHistory.format(astris))")
        }
        return parts.joined(separator: " · ")
    }

    private func sorted(_ rows: [PlayHistory.GameTotal]) -> [PlayHistory.GameTotal] {
        order == .recent ? rows.sorted { $0.lastPlayed > $1.lastPlayed } : rows
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "astris-sessions.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let csv = history.csv { settings.displayName(for: $0.rom, detected: $0.name) }
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared pieces

private struct CoverView: View {
    let titleID: String?
    let covers: CoverResolver
    let size: CGFloat
    /// Overrides the resolved cover (https or file URL).
    var customCover: String? = nil
    /// For the SteamGridDB lookup.
    var name: String? = nil
    var settings: GameSettings = .shared
    @State private var image: NSImage?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
        ZStack {
            shape.fill(.quaternary)
            Image(systemName: "gamecontroller")
                .font(.system(size: size * 0.4))
                .foregroundStyle(.secondary)
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .accessibilityHidden(true)
        .task(id: (customCover ?? "") + (titleID ?? "")) { await resolve() }
    }

    /// The resolver checks candidate URLs in the background: ask again for a few seconds.
    private func resolve() async {
        image = nil
        if let customCover {
            image = await Self.load(customCover)
            return
        }
        guard titleID != nil || name != nil else { return }
        for _ in 0..<20 {
            let link = settings.pickCover(
                switchArt: { titleID.flatMap(covers.cover(for:)) },
                steamGridDB: { name.flatMap { SteamGridDB.shared.cover(forName: $0, apiKey: settings.steamGridDBKey) } })
            if let link {
                image = await Self.load(link)
                return
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    private static func load(_ link: String) async -> NSImage? {
        await withCheckedContinuation { done in
            ImageCache.shared.image(for: link) { done.resume(returning: $0) }
        }
    }
}

private struct EmptyStateView<Actions: View>: View {
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            HStack { actions() }
                .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
