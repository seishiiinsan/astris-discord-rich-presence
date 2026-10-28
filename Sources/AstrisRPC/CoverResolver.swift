import Foundation

/// Picks the first cover URL that actually serves an image for a TitleID.
/// Checks run in the background; until one finishes, `cover(for:)` returns nil.
/// Results are kept on disk (`store`), so known games get their cover right away at next launch.
final class CoverResolver {
    private enum State { case pending, found(String), missing }

    private var cache: [String: State] = [:]
    private let lock = NSLock()
    private let store: DiskStore?
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        return URLSession(configuration: config)
    }()

    init(store: DiskStore? = DiskStore(name: "covers")) {
        self.store = store
    }

    func cover(for titleID: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if cache[titleID] == nil, let stored = store?.lookup(titleID), stored.hit {
            cache[titleID] = stored.value.map(State.found) ?? .missing
        }
        switch cache[titleID] {
        case .found(let url): return url
        case .pending, .missing: return nil
        case nil:
            cache[titleID] = .pending
            resolve(titleID, candidates: Self.candidates(for: titleID))
            return nil
        }
    }

    static func candidates(for titleID: String) -> [String] {
        // Updates and DLC fall back to the base game's art.
        let base = GameDetector.baseTitleID(of: titleID)
        var ids = [titleID]
        if base != titleID { ids.append(base) }
        return ids.flatMap { id in [
            "https://tinfoil.media/ti/\(id)/1024/1024",
            "https://tinfoil.media/ti/\(id)/512/512",
            "https://api.nlib.cc/nx/\(id)/icon/512/512",
        ] }
    }

    private func resolve(_ titleID: String, candidates: [String], offline: Bool = false) {
        guard let first = candidates.first, let url = URL(string: first) else {
            // Offline: retry in a minute instead of remembering "no cover".
            if offline {
                DispatchQueue.global().asyncAfter(deadline: .now() + 60) { [weak self] in self?.forget(titleID) }
            } else {
                set(titleID, .missing)
            }
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        session.dataTask(with: request) { [weak self] _, response, error in
            guard let self else { return }
            let http = response as? HTTPURLResponse
            let isImage = (http?.value(forHTTPHeaderField: "Content-Type") ?? "").hasPrefix("image/")
            if let code = http?.statusCode, (200..<300).contains(code), isImage {
                self.set(titleID, .found(first))
            } else {
                self.resolve(titleID, candidates: Array(candidates.dropFirst()), offline: offline || error != nil)
            }
        }.resume()
    }

    private func forget(_ titleID: String) {
        lock.lock()
        cache[titleID] = nil
        lock.unlock()
    }

    private func set(_ titleID: String, _ state: State) {
        lock.lock()
        cache[titleID] = state
        lock.unlock()
        switch state {
        case .found(let url): store?.set(url, for: titleID)
        case .missing: store?.set(nil, for: titleID)
        case .pending: break
        }
    }
}
