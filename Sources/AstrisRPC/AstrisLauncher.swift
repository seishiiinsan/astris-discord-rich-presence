import AppKit

/// Opens a ROM in Astris.
enum AstrisLauncher {
    static var appURL: URL {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "V380-Ori.Astris")
            ?? URL(fileURLWithPath: "/Applications/Astris.app")
    }

    static func open(_ path: String) {
        Log.shared.add("Launching \((path as NSString).lastPathComponent)")
        NSWorkspace.shared.open([URL(fileURLWithPath: path)], withApplicationAt: appURL, configuration: .init()) { _, error in
            guard let error else { return }
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                NSAlert(error: error).runModal()
            }
        }
    }
}
