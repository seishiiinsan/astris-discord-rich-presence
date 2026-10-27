import AppKit

/// Checks GitHub releases and swaps the running .app for the latest zip asset.
final class Updater {
    struct Release {
        let version: String
        let zipURL: URL
    }

    private static let latestURL =
        URL(string: "https://api.github.com/repos/seishiiinsan/astris-discord-rich-presence/releases/latest")!

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Calls back on the main queue with a release newer than the running app, or nil.
    func check(_ completion: @escaping (Release?) -> Void) {
        var request = URLRequest(url: Self.latestURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let release = data.flatMap(Self.parse)
                .flatMap { Self.isNewer($0.version, than: Self.currentVersion) ? $0 : nil }
            DispatchQueue.main.async { completion(release) }
        }.resume()
    }

    /// Downloads the release, replaces this app bundle and relaunches it.
    func install(_ release: Release, completion: @escaping (Error?) -> Void) {
        URLSession.shared.downloadTask(with: release.zipURL) { file, _, error in
            let result = Result { () throws -> Void in
                if let error { throw error }
                guard let file else { throw URLError(.badServerResponse) }
                try Self.replaceAndRelaunch(zip: file)
            }
            DispatchQueue.main.async {
                switch result {
                case .success: NSApp.terminate(nil)
                case .failure(let error): completion(error)
                }
            }
        }.resume()
    }

    // MARK: - Helpers

    private static func parse(_ data: Data) -> Release? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]],
              let zip = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".zip") == true }),
              let link = zip["browser_download_url"] as? String,
              let url = URL(string: link)
        else { return nil }
        return Release(version: tag.hasPrefix("v") ? String(tag.dropFirst()) : tag, zipURL: url)
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func replaceAndRelaunch(zip: URL) throws {
        let fm = FileManager.default
        let target = Bundle.main.bundlePath
        guard fm.isWritableFile(atPath: (target as NSString).deletingLastPathComponent) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        let work = fm.temporaryDirectory.appendingPathComponent("AstrisRPC-update-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        let archive = work.appendingPathComponent("update.zip")
        try fm.moveItem(at: zip, to: archive)

        try run("/usr/bin/ditto", ["-x", "-k", archive.path, work.path])
        guard let newApp = try fm.contentsOfDirectory(at: work, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" })
        else { throw CocoaError(.fileNoSuchFile) }

        // Swap once this process has exited, then relaunch.
        let script = """
        while kill -0 \(getpid()) 2>/dev/null; do sleep 0.2; done
        rm -rf "\(target)" && mv "\(newApp.path)" "\(target)"
        xattr -dr com.apple.quarantine "\(target)" 2>/dev/null
        open "\(target)"
        rm -rf "\(work.path)"
        """
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script]
        try task.run()
    }

    private static func run(_ tool: String, _ args: [String]) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: tool)
        task.arguments = args
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw CocoaError(.fileReadCorruptFile) }
    }
}
