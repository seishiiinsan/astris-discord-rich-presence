import AppKit
import SwiftUI

/// Every feature, explained in the app (menu → Fonctionnalités…, ⌘?).
enum HelpContent {
    struct Item: Identifiable {
        var id: String { title }
        let title: String
        let text: String
    }

    struct Section: Identifiable {
        var id: String { title }
        let symbol: String
        let title: String
        let items: [Item]
    }

    private static func item(_ fr: String, _ en: String, _ textFR: String, _ textEN: String) -> Item {
        Item(title: L10n.tr(fr, en), text: L10n.tr(textFR, textEN))
    }

    static var sections: [Section] {
        [
            Section(symbol: "text.bubble", title: L10n.tr("Sur Discord", "On Discord"), items: [
                item("En jeu", "In game",
                     "Nom du jeu, jaquette avec badge Astris (version, mode TV ou portable), « Sur Astris · 12 h jouées », chrono de session et boutons « Voir sur l'eShop » et « Astris ».",
                     "Game name, cover with an Astris badge (version, TV or handheld mode), “On Astris · 12 h played”, session timer, “View on eShop” and “Astris” buttons."),
                item("Dans le menu d'Astris", "In Astris' menu", "« Dans le menu » avec le logo Astris.", "“In the menu” with the Astris logo."),
                item("En pause", "Idle",
                     "Sans clavier, souris ni manette pendant le délai choisi (15 min par défaut), Discord affiche « En pause », sans chrono.",
                     "With no keyboard, mouse or controller input for the chosen delay (15 min by default), Discord shows “Idle”, without the timer."),
                item("Multijoueur local", "Local multiplayer",
                     "Si le multijoueur local est actif dans Astris, « Multijoueur local » s'ajoute à la ligne 2.",
                     "When local multiplayer is on in Astris, “Local multiplayer” is added to line 2."),
                item("Textes personnalisés", "Custom text",
                     "Réglages → Discord, ou par jeu dans Réglages → Jeux. Variables : {game}, {played}, {version}, {mode}, {multi}, {status}. Une partie « · » dont la variable est vide est retirée.",
                     "Settings → Discord, or per game in Settings → Games. Variables: {game}, {played}, {version}, {mode}, {multi}, {status}. A “ · ” part whose variable is empty is left out."),
                item("Boutons", "Buttons",
                     "« Voir sur l'eShop » activable, et un bouton perso (libellé + adresse https) à la place d'« Astris ». Discord ne montre pas les boutons sur ton propre profil.",
                     "“View on eShop” can be turned off, and a custom button (label + https address) replaces “Astris”. Discord hides buttons on your own profile."),
                item("Limites de Discord", "Discord limits",
                     "Textes coupés à 128 caractères, boutons invalides retirés. Si Discord refuse quand même, le menu affiche la raison.",
                     "Text cut at 128 characters, invalid buttons removed. If Discord still refuses, the menu shows why."),
            ]),
            Section(symbol: "menubar.rectangle", title: L10n.tr("Menu", "Menu"), items: [
                item("Icône", "Icon",
                     "Manette pleine en jeu, vide sinon, grisée si Astris est fermé ou l'affichage coupé, ⚠︎ si Discord est fermé. Option : chrono de session à côté.",
                     "Filled controller in game, outline otherwise, dimmed when Astris is closed or the presence is off, ⚠︎ if Discord is closed. Option: session timer next to it."),
                item("État", "Status", "Jeu en cours, temps déjà joué ou « En pause », état de Discord (cliquable pour l'ouvrir).", "Current game, time already played or “Idle”, Discord status (click to open it)."),
                item("Lancer un jeu…", "Open a Game…", "Lanceur rapide (⌃⌥⌘G).", "Quick launcher (⌃⌥⌘G)."),
                item("Jeux récents et Favoris", "Recent Games and Favorites", "Les 5 derniers jeux et les jeux étoilés, avec jaquette. Un clic les ouvre dans Astris.", "The last 5 games and starred games, with covers. A click opens them in Astris."),
                item("Dernière capture", "Latest Screenshot", "Copier ou afficher la dernière capture faite dans Astris.", "Copy or show the latest screenshot taken in Astris."),
                item("Manettes", "Controllers", "Manettes connectées et leur batterie.", "Connected controllers and their battery."),
                item("Affichage et confidentialité", "Presence and privacy", "Afficher sur Discord (⌃⌥⌘D), Masquer ce jeu (⌃⌥⌘H), Mode streamer.", "Show on Discord (⌃⌥⌘D), Hide This Game (⌃⌥⌘H), Streamer Mode."),
                item("Mises à jour et diagnostic", "Updates and diagnostics", "Mettre à jour, rechercher les mises à jour, copier le diagnostic.", "Update, check for updates, copy diagnostics."),
            ]),
            Section(symbol: "gamecontroller", title: L10n.tr("Jeux", "Games"), items: [
                item("Bibliothèque", "Library",
                     "Les jeux du dossier choisi (repris d'Astris au premier lancement), avec jaquette, taille, recherche, filtre (favoris, statut) et tri par nom ou taille. Les doublons sont signalés.",
                     "Games in the chosen folder (taken from Astris at first launch), with cover, size, search, filter (favorites, status) and sort by name or size. Duplicates are flagged."),
                item("Lancer", "Open", "Double-clic, bouton « Lancer dans Astris » ou clic droit.", "Double-click, “Open in Astris” button or right-click."),
                item("Suivi", "Tracking", "Statut (À faire, En cours, Terminé, 100 %), note sur 5 et mémo par jeu.", "Status (Backlog, Playing, Finished, 100%), 5-star rating and memo per game."),
                item("Discord par jeu", "Discord per game",
                     "Masquer le jeu, cacher son temps joué, texte propre, nom affiché, jaquette perso (https, ou image glissée : visible dans l'app seulement).",
                     "Hide the game, hide its play time, its own text, display name, custom cover (https, or a dropped image: shown in the app only)."),
                item("Mises à jour de jeux", "Game updates", "« Mise à jour dispo » quand une version plus récente que celle installée existe.", "“Update available” when a newer version than the installed one exists."),
                item("Favoris d'Astris", "Astris favorites", "Importés une fois par jeu ; retirer l'étoile ici est respecté.", "Imported once per game; un-starring here sticks."),
            ]),
            Section(symbol: "chart.bar", title: L10n.tr("Statistiques", "Stats"), items: [
                item("Temps de jeu", "Play time",
                     "Compté par l'app, pauses exclues : cette semaine, au total, par jeu, avec le temps compté par Astris à côté.",
                     "Counted by the app, idle time excluded: this week, in total, per game, with Astris' own count next to it."),
                item("Graphe", "Chart", "7 jours ou 4 semaines.", "7 days or 4 weeks."),
                item("Export", "Export", "CSV, une ligne par session.", "CSV, one line per session."),
            ]),
            Section(symbol: "bell", title: L10n.tr("Notifications", "Notifications"), items: [
                item("Discord", "Discord", "Discord déconnecté pendant que ton jeu était affiché.", "Discord disconnected while your game was shown."),
                item("Mises à jour", "Updates", "Nouvelle version d'Astris RPC.", "New Astris RPC version."),
                item("Bilan de la semaine", "Weekly summary", "Le dimanche soir : temps joué et jeu le plus joué.", "Sunday evening: time played and most played game."),
                item("Rappel de pause", "Break reminder", "« Tu joues depuis 2 h », toutes les 1 h à 3 h (désactivé par défaut).", "“You've been playing for 2 h”, every 1 to 3 h (off by default)."),
                item("Paliers et records", "Milestones and records", "10, 25, 50, 100, 200, 500 h sur un jeu, et plus longue session jamais comptée.", "10, 25, 50, 100, 200, 500 h on a game, and longest session ever counted."),
                item("Batterie", "Battery", "Manette sous 20 %.", "Controller under 20%."),
                item("Captures", "Screenshots", "À chaque capture faite dans Astris, avec copie automatique en option.", "On each screenshot taken in Astris, with optional automatic copy."),
            ]),
            Section(symbol: "wrench.and.screwdriver", title: L10n.tr("Outils", "Tools"), items: [
                item("Sauvegardes des jeux", "Game saves",
                     "Zip des saves d'Astris dans ~/Documents/Astris RPC : à la demande, à la fermeture d'un jeu ou chaque semaine. Les 20 dernières sont gardées. Restauration Astris fermé, les saves actuelles mises de côté.",
                     "Zip of Astris' saves in ~/Documents/Astris RPC: on demand, when a game closes or weekly. The last 20 are kept. Restore with Astris closed, current saves kept aside."),
                item("Export / import des réglages", "Settings export / import", "Un fichier avec tous les réglages, les favoris et l'historique, pour changer de Mac.", "One file with every setting, favorites and history, to move to another Mac."),
                item("Dépannage", "Troubleshooting", "Journal sur disque (~/Library/Logs/AstrisRPC.log), vider le cache des jaquettes, copier le diagnostic.", "Log file (~/Library/Logs/AstrisRPC.log), clear the cover cache, copy diagnostics."),
            ]),
            Section(symbol: "keyboard", title: L10n.tr("Raccourcis et liens", "Shortcuts and links"), items: [
                item("⌃⌥⌘D", "⌃⌥⌘D", "Afficher / couper l'affichage sur Discord.", "Turn the Discord presence on or off."),
                item("⌃⌥⌘H", "⌃⌥⌘H", "Masquer / réafficher le jeu en cours.", "Hide or show the current game."),
                item("⌃⌥⌘G", "⌃⌥⌘G", "Lanceur rapide : tape un nom, ↑↓ puis ↩︎.", "Quick launcher: type a name, ↑↓ then ↩︎."),
                item("astrisrpc://", "astrisrpc://",
                     "on, off, toggle, hide-game, streamer (?on=1 / 0), launch?game=Zelda, settings. Pour Raccourcis, Raycast, Alfred ou open dans le Terminal.",
                     "on, off, toggle, hide-game, streamer (?on=1 / 0), launch?game=Zelda, settings. For Shortcuts, Raycast, Alfred or open in Terminal."),
            ]),
            Section(symbol: "photo", title: L10n.tr("Jaquettes", "Covers"), items: [
                item("Ordre", "Order",
                     "Jaquette perso (https), puis tinfoil.media et api.nlib.cc (TitleID puis jeu de base), puis SteamGridDB par nom si une clé est réglée (ou en premier), sinon logo Astris.",
                     "Custom cover (https), then tinfoil.media and api.nlib.cc (TitleID then base game), then SteamGridDB by name when a key is set (or first), else the Astris logo."),
                item("Cache", "Cache", "Adresses gardées 30 jours, absences 3 jours, images téléchargées une seule fois.", "Addresses kept 30 days, misses 3 days, images downloaded once."),
            ]),
            Section(symbol: "lock", title: L10n.tr("Confidentialité", "Privacy"), items: [
                item("Liste noire", "Blacklist", "Un jeu masqué apparaît « En jeu · Sur Astris », sans nom ni jaquette.", "A hidden game shows as “Playing · On Astris”, with no name or cover."),
                item("Mode streamer", "Streamer mode", "Cache d'un coup temps joué, bouton eShop et/ou jaquettes.", "Hides play time, the eShop button and/or covers in one switch."),
                item("Ce qui sort du Mac", "What leaves the Mac",
                     "Discord (socket local), les sources de jaquettes, api.nlib.cc et GitHub (mises à jour). Le diagnostic ne contient que des noms de fichiers.",
                     "Discord (local socket), cover sources, api.nlib.cc and GitHub (updates). Diagnostics only contain file names."),
            ]),
        ]
    }

    /// Sections keeping only the items that match `query`.
    static func filtered(_ query: String, in sections: [Section] = sections) -> [Section] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return sections }
        return sections.compactMap { section in
            if section.title.localizedCaseInsensitiveContains(q) { return section }
            let items = section.items.filter { $0.title.localizedCaseInsensitiveContains(q) || $0.text.localizedCaseInsensitiveContains(q) }
            return items.isEmpty ? nil : Section(symbol: section.symbol, title: section.title, items: items)
        }
    }
}

/// One help window, from the menu or the Settings.
enum HelpPresenter {
    private static var controller: HelpWindowController?

    static func show() {
        if controller == nil { controller = HelpWindowController() }
        controller?.show()
    }
}

final class HelpWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: HelpView()))
        window.title = L10n.tr("Fonctionnalités d'Astris RPC", "Astris RPC Features")
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 640, height: SettingsLayout.height))
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct HelpView: View {
    @State private var query = ""

    var body: some View {
        let sections = HelpContent.filtered(query)
        VStack(spacing: 0) {
            TextField(L10n.tr("Rechercher une fonctionnalité", "Search a feature"), text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(12)
            Divider()
            if sections.isEmpty {
                Text(L10n.tr("Rien trouvé.", "Nothing found."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sections) { section in
                        SwiftUI.Section {
                            ForEach(section.items) { item in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title).font(.headline)
                                    Text(item.text).foregroundStyle(.secondary).textSelection(.enabled)
                                }
                                .padding(.vertical, 3)
                            }
                        } header: {
                            Label(section.title, systemImage: section.symbol).font(.title3.weight(.semibold))
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 480, minHeight: 360)
    }
}
