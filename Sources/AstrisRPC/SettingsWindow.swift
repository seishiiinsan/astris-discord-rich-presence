import AppKit
import ServiceManagement
import SwiftUI

/// Native macOS Settings window: toolbar tabs (General, Games), opened with ⌘,.
final class SettingsWindowController: NSWindowController {
    convenience init(settings: GameSettings, covers: CoverResolver, recents: RecentGames) {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar

        let general = NSHostingController(rootView: GeneralSettingsView(settings: settings, recents: recents))
        let discord = NSHostingController(rootView: DiscordSettingsView(settings: settings))
        let games = NSHostingController(rootView: GamesSettingsView(settings: settings, covers: covers, recents: recents))
        general.sizingOptions = .preferredContentSize
        discord.sizingOptions = .preferredContentSize
        games.sizingOptions = .preferredContentSize

        // The window title follows the selected tab.
        general.title = L10n.tr("Général", "General")
        discord.title = "Discord"
        games.title = L10n.tr("Jeux", "Games")

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

    /// Folder of the last game seen running, offered when no folder is set yet.
    static func suggestion(from recents: RecentGames) -> URL? {
        recents.entries.first.map { URL(fileURLWithPath: $0.romPath).deletingLastPathComponent() }
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
                Picker(L10n.tr("Afficher « En pause » après", "Show “Idle” after"), selection: $settings.idleMinutes) {
                    ForEach(GameSettings.idleChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? L10n.tr("Jamais", "Never") : "\(minutes) min").tag(minutes)
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
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
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
                    "Variables : {game} nom du jeu, {played} temps déjà joué, {version} version du jeu. Une partie « · » dont la variable est inconnue est retirée. Vide : texte par défaut.",
                    "Variables: {game} game name, {played} time already played, {version} game version. A “ · ” part whose variable is unknown is left out. Empty: default text."))
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
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
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

    private var filtered: [GameLibrary.Game] {
        guard !search.isEmpty else { return games }
        return games.filter {
            settings.displayName(for: $0.url.path, detected: $0.name).localizedCaseInsensitiveContains(search)
        }
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
        .frame(width: 700, height: 460)
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
                .padding(10)
            List(filtered, selection: $selection) { game in
                GameRow(game: game, settings: settings, covers: covers).tag(game.id)
            }
            .listStyle(.sidebar)
            Divider()
            Text(L10n.tr("\(games.count) jeux · \(hiddenCount) masqués", "\(games.count) games · \(hiddenCount) hidden"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
        }
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

    var body: some View {
        let hidden = settings.isHidden(game.url.path)
        HStack(spacing: 10) {
            CoverView(titleID: game.titleID, covers: covers, size: 32)
                .opacity(hidden ? 0.45 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.displayName(for: game.url.path, detected: game.name))
                    .lineLimit(1)
                    .foregroundStyle(hidden ? .secondary : .primary)
                if hidden {
                    Text(L10n.tr("Masqué sur Discord", "Hidden on Discord"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
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

    private var path: String { game.url.path }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                CoverView(titleID: game.titleID, covers: covers, size: 112)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                Text(settings.displayName(for: path, detected: game.name))
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(game.url.lastPathComponent)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)

            Form {
                Section {
                    Toggle(L10n.tr("Afficher sur Discord", "Show on Discord"), isOn: Binding(
                        get: { !settings.isHidden(path) },
                        set: { settings.setHidden(!$0, for: path) }))
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
            .scrollDisabled(true)

            HStack {
                Button(L10n.tr("Afficher dans le Finder", "Show in Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([game.url])
                }
                Spacer()
            }
            .padding([.horizontal, .bottom], 20)
        }
        .onAppear { name = settings.prefs(for: path).customName ?? "" }
    }
}

// MARK: - Shared pieces

private struct CoverView: View {
    let titleID: String?
    let covers: CoverResolver
    let size: CGFloat
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
        .task(id: titleID) { await resolve() }
    }

    /// The resolver checks candidate URLs in the background: ask again for a few seconds.
    private func resolve() async {
        guard let titleID else { return }
        for _ in 0..<20 {
            if let link = covers.cover(for: titleID) {
                image = await withCheckedContinuation { done in
                    ImageCache.shared.image(for: link) { done.resume(returning: $0) }
                }
                return
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
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
