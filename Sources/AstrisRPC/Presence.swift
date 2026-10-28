import Foundation

struct Presence: Equatable {
    var details: String
    var state: String?
    var start: Date?
    var image: String?
    var imageText: String?
    var buttons: [(label: String, url: String)] = []

    static func == (a: Presence, b: Presence) -> Bool {
        a.details == b.details && a.state == b.state && a.start == b.start
            && a.image == b.image && a.imageText == b.imageText
            && a.buttons.map { $0.label } == b.buttons.map { $0.label } && a.buttons.map { $0.url } == b.buttons.map { $0.url }
    }

    /// Discord refuses the whole activity when one field breaks its limits, so fix them here.
    var activity: [String: Any] {
        var a: [String: Any] = ["type": 0, "details": Self.field(details)]
        if let state { a["state"] = Self.field(state) }
        if let start { a["timestamps"] = ["start": Int(start.timeIntervalSince1970)] }
        if let image, Self.isWebURL(image, max: 256) {
            var assets: [String: Any] = ["large_image": image]
            if let imageText { assets["large_text"] = Self.field(imageText) }
            a["assets"] = assets
        }
        let valid = buttons
            .filter { !$0.label.trimmingCharacters(in: .whitespaces).isEmpty && Self.isWebURL($0.url, max: 512) }
            .prefix(2)
        if !valid.isEmpty {
            a["buttons"] = valid.map { ["label": Self.field($0.label, max: 32), "url": $0.url] }
        }
        return a
    }

    /// Text fields: 2 to 128 characters (labels: 32).
    static func field(_ text: String, max: Int = 128) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count > max { t = String(t.prefix(max - 1)) + "…" }
        // Braille blank: invisible, but Discord counts it.
        while t.count < 2 { t += "\u{2800}" }
        return t
    }

    static func isWebURL(_ link: String, max: Int) -> Bool {
        guard link.count <= max, let url = URL(string: link), let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "https" || scheme == "http") && url.host != nil
    }
}
