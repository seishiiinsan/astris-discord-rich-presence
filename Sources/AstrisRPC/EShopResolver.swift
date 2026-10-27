import Foundation

/// Finds the eShop page of a game from its TitleID (via its NSUID on api.nlib.cc).
/// Falls back to a Nintendo search link until (or unless) the lookup succeeds.
final class EShopResolver {
    private var cache: [String: String?] = [:]
    private let lock = NSLock()
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        return URLSession(configuration: config)
    }()

    func url(titleID: String?, name: String) -> String {
        guard let titleID else { return Self.searchURL(for: name) }
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[titleID] { return cached ?? Self.searchURL(for: name) }
        cache[titleID] = .some(nil)
        lookup(titleID)
        return Self.searchURL(for: name)
    }

    static func searchURL(for name: String) -> String {
        let query = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return L10n.isFrench
            ? "https://www.nintendo.com/fr-fr/Rechercher/Rechercher-299117.html?q=\(query)"
            : "https://www.nintendo.com/us/search/#q=\(query)"
    }

    static func titleURL(nsuid: String) -> String {
        L10n.isFrench ? "https://ec.nintendo.com/FR/fr/titles/\(nsuid)" : "https://ec.nintendo.com/US/en/titles/\(nsuid)"
    }

    /// Accepts "nsuId" / "nsuid" / "nsu_id" as a number or a string.
    static func nsuid(in json: [String: Any]) -> String? {
        for key in ["nsuId", "nsuid", "nsu_id", "NSUID"] {
            if let n = json[key] as? NSNumber { return n.stringValue }
            if let s = json[key] as? String, !s.isEmpty, s.allSatisfy(\.isNumber) { return s }
        }
        return nil
    }

    private func lookup(_ titleID: String) {
        guard let url = URL(string: "https://api.nlib.cc/nx/\(titleID)") else { return }
        session.dataTask(with: url) { [weak self] data, response, _ in
            guard let self,
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let nsuid = Self.nsuid(in: json)
            else { return }
            lock.lock()
            cache[titleID] = .some(Self.titleURL(nsuid: nsuid))
            lock.unlock()
        }.resume()
    }
}
