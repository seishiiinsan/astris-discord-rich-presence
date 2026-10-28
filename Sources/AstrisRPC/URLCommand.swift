import Foundation

/// `astrisrpc://…` links, for Shortcuts, Raycast, Alfred or a Terminal `open`.
enum URLCommand: Equatable {
    case show, hide, toggle
    case hideGame
    case streamer(Bool?)
    case launch(String)
    case settings

    static let scheme = "astrisrpc"

    /// astrisrpc://on | off | toggle | hide-game | streamer[?on=1|0] | launch?game=Zelda | settings
    static func parse(_ url: URL) -> URLCommand? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        // "astrisrpc://toggle" or "astrisrpc:toggle" (no host, no path for Foundation): read the text itself.
        let rest = url.absoluteString.dropFirst(scheme.count + 1).drop { $0 == "/" }
        let name = String(rest.prefix { $0 != "?" && $0 != "/" && $0 != "#" }).lowercased()
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ key: String) -> String? { query.first { $0.name == key }?.value }
        switch name {
        case "on", "show": return .show
        case "off", "hide": return .hide
        case "toggle": return .toggle
        case "hide-game", "hidegame": return .hideGame
        case "streamer":
            switch value("on")?.lowercased() {
            case "1", "true", "yes": return .streamer(true)
            case "0", "false", "no": return .streamer(false)
            default: return .streamer(nil)
            }
        case "launch", "open", "play":
            guard let game = value("game") ?? value("name"), !game.isEmpty else { return nil }
            return .launch(game)
        case "settings": return .settings
        default: return nil
        }
    }

    /// Best ROM for a typed name: exact normalized match first, then the shortest name containing it.
    static func match(_ query: String, in games: [(path: String, name: String)]) -> String? {
        let q = GameDetector.normalize(query)
        guard !q.isEmpty else { return nil }
        if let exact = games.first(where: { GameDetector.normalize($0.name) == q }) { return exact.path }
        return games
            .filter { GameDetector.normalize($0.name).contains(q) }
            .min { $0.name.count < $1.name.count }?.path
    }
}
