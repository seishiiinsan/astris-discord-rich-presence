import AppKit
import SwiftUI

/// ⌃⌥⌘G: a small floating search to open a game in Astris by typing its name.
final class LauncherModel: ObservableObject {
    struct Entry: Identifiable, Equatable {
        var id: String { path }
        let path: String
        let name: String
        let titleID: String?
    }

    @Published var query = "" { didSet { selected = 0 } }
    @Published var selected = 0
    /// Recents first, then favorites, then the rest of the library.
    @Published var entries: [Entry] = []

    static let limit = 8

    var results: [Entry] {
        Self.search(query, in: entries)
    }

    /// Prefix matches before inner matches, first-listed (recent) first.
    static func search(_ query: String, in entries: [Entry]) -> [Entry] {
        let q = GameDetector.normalize(query)
        guard !q.isEmpty else { return Array(entries.prefix(limit)) }
        let scored = entries.enumerated().compactMap { index, entry -> (Int, Int, Entry)? in
            let name = GameDetector.normalize(entry.name)
            if name.hasPrefix(q) { return (0, index, entry) }
            if name.contains(q) { return (1, index, entry) }
            return nil
        }
        return scored.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.prefix(limit).map(\.2)
    }

    /// Keeps the first occurrence of each ROM.
    static func merge(_ lists: [[Entry]]) -> [Entry] {
        var seen = Set<String>()
        return lists.flatMap { $0 }.filter { seen.insert($0.path).inserted }
    }

    func move(_ delta: Int) {
        let count = results.count
        guard count > 0 else { return }
        selected = (selected + delta + count) % count
    }
}

final class QuickLauncher: NSObject, NSWindowDelegate {
    let model = LauncherModel()
    var onLaunch: ((String) -> Void)?
    private var panel: NSPanel?
    private var monitor: Any?

    func toggle(covers: CoverResolver, settings: GameSettings) {
        if panel?.isVisible == true { close(); return }
        model.query = ""
        let panel = self.panel ?? makePanel(covers: covers, settings: settings)
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            switch event.keyCode {
            case 125: self.model.move(1); return nil      // ↓
            case 126: self.model.move(-1); return nil     // ↑
            case 53: self.close(); return nil              // esc
            case 36, 76: self.launchSelected(); return nil // return, enter
            default: return event
            }
        }
    }

    private func makePanel(covers: CoverResolver, settings: GameSettings) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: LauncherView(
            model: model, covers: covers, settings: settings,
            launch: { [weak self] path in self?.launch(path) }))
        return panel
    }

    private func launchSelected() {
        let results = model.results
        guard results.indices.contains(model.selected) else { NSSound.beep(); return }
        launch(results[model.selected].path)
    }

    private func launch(_ path: String) {
        close()
        onLaunch?(path)
    }

    func close() {
        panel?.orderOut(nil)
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    func windowWillClose(_ notification: Notification) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

private struct LauncherView: View {
    @ObservedObject var model: LauncherModel
    let covers: CoverResolver
    @ObservedObject var settings: GameSettings
    let launch: (String) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller").font(.title2).foregroundStyle(.secondary)
                TextField(L10n.tr("Lancer un jeu…", "Open a game…"), text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .focused($focused)
            }
            .padding(16)
            Divider()
            let results = model.results
            if results.isEmpty {
                Text(model.entries.isEmpty
                     ? L10n.tr("Aucun jeu : choisis le dossier des jeux dans Réglages.", "No games: choose the games folder in Settings.")
                     : L10n.tr("Aucun jeu ne correspond.", "No game matches."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, entry in
                            row(entry, selected: index == model.selected)
                                .onTapGesture { launch(entry.path) }
                        }
                    }
                    .padding(8)
                }
            }
            Divider()
            Text(L10n.tr("↑↓ choisir · ↩︎ lancer · esc fermer", "↑↓ select · ↩︎ open · esc close"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
        }
        .frame(width: 520, height: 360)
        .onAppear { focused = true }
    }

    private func row(_ entry: LauncherModel.Entry, selected: Bool) -> some View {
        HStack(spacing: 10) {
            LauncherCover(link: settings.prefs(for: entry.path).customCover ?? entry.titleID.flatMap(covers.cover(for:)))
            Text(settings.displayName(for: entry.path, detected: entry.name)).lineLimit(1)
            Spacer()
            if settings.isFavorite(entry.path) { Image(systemName: "star.fill").foregroundStyle(.yellow) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor.opacity(0.25) : .clear))
        .contentShape(Rectangle())
    }
}

private struct LauncherCover: View {
    let link: String?
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(.quaternary)
            if let image { Image(nsImage: image).resizable().scaledToFill() }
        }
        .frame(width: 32, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task(id: link) {
            guard let link else { image = nil; return }
            image = await withCheckedContinuation { done in
                ImageCache.shared.image(for: link) { done.resume(returning: $0) }
            }
        }
    }
}
