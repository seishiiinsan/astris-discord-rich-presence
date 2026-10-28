import Foundation

/// Exports every Astris RPC setting (and the play history) to one file, and back.
enum SettingsTransfer {
    static let fileExtension = "astrisrpc"

    struct Archive {
        var defaults: [String: Any]
        var history: Data?
    }

    static func encode(_ archive: Archive) throws -> Data {
        var root: [String: Any] = ["format": 1, "defaults": archive.defaults]
        if let history = archive.history { root["history"] = history }
        return try PropertyListSerialization.data(fromPropertyList: root, format: .xml, options: 0)
    }

    static func decode(_ data: Data) throws -> Archive {
        guard let root = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              root["format"] as? Int == 1,
              let defaults = root["defaults"] as? [String: Any]
        else { throw CocoaError(.fileReadCorruptFile) }
        return Archive(defaults: defaults, history: root["history"] as? Data)
    }

    static var domain: String { Bundle.main.bundleIdentifier ?? "com.seishin.astris-rpc" }
    static var historyFile: URL? { AppPaths.support?.appendingPathComponent("history.json") }

    static func export(to url: URL, history: PlayHistory) throws {
        history.save()
        let defaults = UserDefaults.standard.persistentDomain(forName: domain) ?? [:]
        let data = try encode(Archive(defaults: defaults, history: historyFile.flatMap { try? Data(contentsOf: $0) }))
        try data.write(to: url, options: .atomic)
    }

    /// Replaces settings and history; the app relaunches to load them.
    static func importFile(_ url: URL) throws {
        let archive = try decode(Data(contentsOf: url))
        UserDefaults.standard.setPersistentDomain(archive.defaults, forName: domain)
        UserDefaults.standard.synchronize()
        if let history = archive.history, let file = historyFile { try history.write(to: file, options: .atomic) }
    }
}
