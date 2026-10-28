import AppKit
import CryptoKit

/// Where the app keeps its files.
enum AppPaths {
    /// ~/Library/Application Support/AstrisRPC
    static let support = folder(.applicationSupportDirectory)
    /// ~/Library/Caches/AstrisRPC
    static let caches = folder(.cachesDirectory)

    private static func folder(_ kind: FileManager.SearchPathDirectory) -> URL? {
        guard let base = FileManager.default.urls(for: kind, in: .userDomainMask).first else { return nil }
        let url = base.appendingPathComponent("AstrisRPC", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

/// Small persisted key → value map (TitleID → cover URL, eShop link…).
/// A nil value records "looked up, nothing found" and expires sooner, so it gets retried.
final class DiskStore {
    struct Entry: Codable, Equatable {
        let value: String?
        let date: Date
    }

    static let foundLifetime: TimeInterval = 30 * 86400
    static let missingLifetime: TimeInterval = 3 * 86400

    private let file: URL?
    private let lock = NSLock()
    private var entries: [String: Entry]

    init(file: URL?) {
        self.file = file
        entries = file.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode([String: Entry].self, from: $0) } ?? [:]
    }

    convenience init(name: String) {
        self.init(file: AppPaths.caches?.appendingPathComponent("\(name).json"))
    }

    /// `hit` is false when the key is unknown or expired.
    func lookup(_ key: String, now: Date = Date()) -> (hit: Bool, value: String?) {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[key] else { return (false, nil) }
        let lifetime = entry.value == nil ? Self.missingLifetime : Self.foundLifetime
        guard now.timeIntervalSince(entry.date) < lifetime else { return (false, nil) }
        return (true, entry.value)
    }

    func set(_ value: String?, for key: String, now: Date = Date()) {
        lock.lock()
        entries[key] = Entry(value: value, date: now)
        let data = try? JSONEncoder().encode(entries)
        lock.unlock()
        if let file, let data { try? data.write(to: file, options: .atomic) }
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }
}

/// Downloaded cover images, kept on disk so menus and Settings don't refetch them at each launch.
final class ImageCache {
    static let shared = ImageCache(directory: AppPaths.caches?.appendingPathComponent("Images", isDirectory: true))

    private let directory: URL?
    private let memory = NSCache<NSString, NSImage>()
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    init(directory: URL?) {
        self.directory = directory
        if let directory { try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
    }

    static func fileName(for link: String) -> String {
        SHA256.hash(data: Data(link.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Memory, then disk, then network. Calls back on the main queue.
    func image(for link: String, completion: @escaping (NSImage?) -> Void) {
        if let image = memory.object(forKey: link as NSString) {
            completion(image)
            return
        }
        let file = directory?.appendingPathComponent(Self.fileName(for: link))
        if let file, let data = try? Data(contentsOf: file), let image = NSImage(data: data) {
            memory.setObject(image, forKey: link as NSString)
            completion(image)
            return
        }
        // Local images (custom covers picked from disk) are read as is.
        guard let url = URL(string: link), url.scheme == "https" || url.scheme == "http" else {
            let image = URL(string: link).flatMap { $0.isFileURL ? NSImage(contentsOf: $0) : nil }
            completion(image)
            return
        }
        session.dataTask(with: url) { [weak self] data, response, _ in
            let ok = ((response as? HTTPURLResponse)?.statusCode).map { (200..<300).contains($0) } ?? false
            let image = ok ? data.flatMap(NSImage.init(data:)) : nil
            if let image, let data, let file { try? data.write(to: file, options: .atomic) }
            DispatchQueue.main.async {
                if let image { self?.memory.setObject(image, forKey: link as NSString) }
                completion(image)
            }
        }.resume()
    }

    /// Size of the cached images, for the diagnostic.
    var diskSize: Int {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
        else { return 0 }
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0) }
    }

    func clear() {
        memory.removeAllObjects()
        guard let directory else { return }
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
