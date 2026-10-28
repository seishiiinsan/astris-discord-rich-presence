import Foundation

/// Latest update build of each game (api.nlib.cc), to flag games whose installed update is behind.
final class GameUpdates: ObservableObject {
    static let shared = GameUpdates()

    /// Base TitleID → latest build number.
    @Published private(set) var latest: [String: Int] = [:]

    private var asked: Set<String> = []
    private let store: DiskStore?
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config)
    }()

    /// Versions change: re-ask after a day.
    init(store: DiskStore? = DiskStore(name: "versions", foundLifetime: 86400, missingLifetime: 86400)) {
        self.store = store
    }

    /// "version" as a number or digits, sometimes under another key.
    static func build(in json: [String: Any]) -> Int? {
        for key in ["version", "latestVersion", "latest_version"] {
            if let n = json[key] as? NSNumber { return n.intValue }
            if let s = json[key] as? String, let n = Int(s) { return n }
        }
        return nil
    }

    /// Main queue. Starts a lookup the first time; `latest` publishes the answer.
    func check(_ titleID: String) {
        let base = GameDetector.baseTitleID(of: titleID)
        guard asked.insert(base).inserted else { return }
        if let stored = store?.lookup(base), stored.hit {
            if let build = stored.value.flatMap(Int.init) { latest[base] = build }
            return
        }
        guard let url = URL(string: "https://api.nlib.cc/nx/\(base)") else { return }
        session.dataTask(with: url) { [weak self] data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode
            let build = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }.flatMap(Self.build)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let build { self.latest[base] = build }
                if error == nil, status == 200 || status == 404 { self.store?.set(build.map(String.init), for: base) }
                else { self.asked.remove(base) }
            }
        }.resume()
    }

    /// Latest build when it's newer than the installed one.
    func newerBuild(titleID: String?, installed: Int?) -> Int? {
        guard let titleID, let latest = latest[GameDetector.baseTitleID(of: titleID)], latest > (installed ?? 0) else { return nil }
        return latest
    }

    /// Switch builds count updates in steps of 65536.
    static func label(_ build: Int) -> String {
        build % 65536 == 0 ? L10n.tr("màj \(build / 65536)", "update \(build / 65536)") : "v\(build)"
    }
}
