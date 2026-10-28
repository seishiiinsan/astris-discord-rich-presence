import Foundation

/// Optional cover source (needs the user's own API key, steamgriddb.com → Preferences → API).
/// Looks games up by name, so it also covers homebrew and games without a TitleID.
final class SteamGridDB {
    static let shared = SteamGridDB()

    private enum State { case pending, found(String), missing }

    private var cache: [String: State] = [:]
    private let lock = NSLock()
    private let store: DiskStore?
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    init(store: DiskStore? = DiskStore(name: "steamgriddb")) {
        self.store = store
    }

    /// Square art for `name`, nil until the lookup finishes (or without a key).
    func cover(forName name: String, apiKey: String?) -> String? {
        guard let apiKey, !apiKey.isEmpty else { return nil }
        let key = GameDetector.normalize(name)
        guard !key.isEmpty else { return nil }
        lock.lock()
        if cache[key] == nil, let stored = store?.lookup(key), stored.hit {
            cache[key] = stored.value.map(State.found) ?? .missing
        }
        let state = cache[key]
        if state == nil { cache[key] = .pending }
        lock.unlock()
        switch state {
        case .found(let url): return url
        case .pending, .missing: return nil
        case nil:
            // Outside the lock: `finish` takes it.
            lookup(name, key: key, apiKey: apiKey)
            return nil
        }
    }

    static func searchURL(_ name: String) -> URL? {
        let term = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? ""
        return URL(string: "https://www.steamgriddb.com/api/v2/search/autocomplete/\(term)")
    }

    static func gridsURL(gameID: Int) -> URL? {
        URL(string: "https://www.steamgriddb.com/api/v2/grids/game/\(gameID)?dimensions=512x512,1024x1024&types=static")
    }

    /// `{"success": true, "data": [...]}` → data.
    static func data(_ body: Data?) -> [[String: Any]]? {
        guard let body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              json["success"] as? Bool == true
        else { return nil }
        return json["data"] as? [[String: Any]]
    }

    private func lookup(_ name: String, key: String, apiKey: String) {
        guard let search = Self.searchURL(name) else { return finish(key, nil, remember: true) }
        get(search, apiKey: apiKey) { [weak self] body, ok in
            guard let self else { return }
            guard ok else { return finish(key, nil, remember: false) }
            guard let id = (Self.data(body)?.first?["id"] as? NSNumber)?.intValue, let grids = Self.gridsURL(gameID: id) else {
                return finish(key, nil, remember: true)
            }
            get(grids, apiKey: apiKey) { [weak self] body, ok in
                let url = Self.data(body)?.first?["url"] as? String
                self?.finish(key, url, remember: ok)
            }
        }
    }

    /// `ok` is false on network or auth errors: those are retried later, not remembered.
    private func get(_ url: URL, apiKey: String, completion: @escaping (Data?, Bool) -> Void) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        session.dataTask(with: request) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401 { Log.shared.add("SteamGridDB: API key refused") }
            completion(data, error == nil && (status == 200 || status == 404))
        }.resume()
    }

    private func finish(_ key: String, _ url: String?, remember: Bool) {
        lock.lock()
        // A failed request is retried after a minute rather than at every poll.
        cache[key] = url.map(State.found) ?? .missing
        lock.unlock()
        if remember {
            store?.set(url, for: key)
        } else {
            DispatchQueue.global().asyncAfter(deadline: .now() + 60) { [weak self] in
                guard let self else { return }
                lock.lock()
                cache[key] = nil
                lock.unlock()
            }
        }
    }
}
