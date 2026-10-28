import XCTest
@testable import AstrisRPC

final class GameDetectorTests: XCTestCase {
    func testParsePlayed() {
        XCTAssertEqual(GameDetector.parsePlayed("00:45:00"), 2700)
        XCTAssertEqual(GameDetector.parsePlayed("12:00:00.1234567")!, 43200.1234567, accuracy: 0.001)
        XCTAssertEqual(GameDetector.parsePlayed("1.02:03:04"), 86400 + 7384)
        XCTAssertEqual(GameDetector.parsePlayed(NSNumber(value: 90)), 90)
        XCTAssertEqual(GameDetector.parsePlayed("120"), 120)
        XCTAssertNil(GameDetector.parsePlayed(nil))
    }

    func testCleanName() {
        XCTAssertEqual(GameDetector.cleanName("New Super Mario Bros U Deluxe"), "New Super Mario Bros U Deluxe")
        XCTAssertEqual(GameDetector.cleanName("Super_Mario [0100EA80032EA000][v0] (EU)"), "Super Mario")
        XCTAssertEqual(GameDetector.cleanName("[only tags]"), "[only tags]")
    }

    func testTitleID() {
        XCTAssertEqual(GameDetector.titleID(in: "Mario [0100EA80032EA000][v0]"), "0100EA80032EA000")
        XCTAssertNil(GameDetector.titleID(in: "New Super Mario Bros U Deluxe"))
    }

    func testParseDate() {
        let date = GameDetector.parseDate("2026-10-27T10:44:12.1234567Z")
        XCTAssertEqual(date?.timeIntervalSince1970, 1_793_097_852)
        XCTAssertNil(GameDetector.parseDate("bad"))
    }

    func testIsROM() {
        XCTAssertTrue(GameDetector.isROM("/Games/Mario.xcz"))
        XCTAssertTrue(GameDetector.isROM("/Games/Zelda.NSP"))
        XCTAssertFalse(GameDetector.isROM("/Astris/bis/system/registered/abc.nca/00"))
    }
}

final class UpdaterTests: XCTestCase {
    func testIsNewer() {
        XCTAssertTrue(Updater.isNewer("1.2.1", than: "1.2.0"))
        XCTAssertTrue(Updater.isNewer("1.10.0", than: "1.9.9"))
        XCTAssertTrue(Updater.isNewer("2", than: "1.9"))
        XCTAssertFalse(Updater.isNewer("1.2.0", than: "1.2.0"))
        XCTAssertFalse(Updater.isNewer("1.2", than: "1.2.0"))
        XCTAssertFalse(Updater.isNewer("1.1.9", than: "1.2.0"))
    }

    func testReleaseNotes() {
        let body = """
        ## What's Changed
        * feat: release en .dmg by @seishiiinsan in https://github.com/x/y/pull/11
        * fix: truc by @someone

        ## New Contributors
        * @seishiiinsan made their first contribution in https://github.com/x/y/pull/1

        **Full Changelog**: https://github.com/x/y/compare/v1...v2
        """
        XCTAssertEqual(Updater.releaseNotes(body), "• feat: release en .dmg\n• fix: truc")
        XCTAssertNil(Updater.releaseNotes("**Full Changelog**: x"))
    }

    func testParseRelease() throws {
        let json = """
        {"tag_name": "v1.3.0", "body": "* feat: x by @a in u",
         "assets": [{"name": "AstrisRPC.dmg", "browser_download_url": "https://e/a.dmg"},
                    {"name": "AstrisRPC.zip", "browser_download_url": "https://e/a.zip"}]}
        """
        let release = try XCTUnwrap(Updater.parse(Data(json.utf8)))
        XCTAssertEqual(release.version, "1.3.0")
        XCTAssertEqual(release.zipURL.absoluteString, "https://e/a.zip")
        XCTAssertEqual(release.notes, "• feat: x")
    }
}

final class PresenceTests: XCTestCase {
    func testFormatPlayed() {
        XCTAssertNil(AppDelegate.formatPlayed(30))
        XCTAssertEqual(AppDelegate.formatPlayed(45 * 60), "45 min")
        XCTAssertEqual(AppDelegate.formatPlayed(12.5 * 3600), "12 h")
    }

    func testCoverCandidates() {
        let update = CoverResolver.candidates(for: "0100EA80032EA800")
        XCTAssertEqual(update.first, "https://tinfoil.media/ti/0100EA80032EA800/1024/1024")
        XCTAssertTrue(update.contains("https://tinfoil.media/ti/0100EA80032EA000/512/512"))
        XCTAssertEqual(CoverResolver.candidates(for: "0100EA80032EA000").count, 3)
    }

    func testEShop() {
        XCTAssertEqual(EShopResolver.nsuid(in: ["nsuId": NSNumber(value: 70010000012345)]), "70010000012345")
        XCTAssertEqual(EShopResolver.nsuid(in: ["nsuid": "70010000012345"]), "70010000012345")
        XCTAssertNil(EShopResolver.nsuid(in: ["nsuId": ""]))
        L10n.isFrench = true
        XCTAssertTrue(EShopResolver.searchURL(for: "Super Mario").hasSuffix("?q=Super%20Mario"))
        XCTAssertTrue(EShopResolver.titleURL(nsuid: "1").contains("/FR/fr/"))
        L10n.isFrench = false
        XCTAssertTrue(EShopResolver.searchURL(for: "Super Mario").hasSuffix("#q=Super%20Mario"))
        XCTAssertTrue(EShopResolver.titleURL(nsuid: "1").contains("/US/en/"))
    }

    func testL10n() {
        L10n.isFrench = true
        XCTAssertEqual(L10n.tr("Oui", "Yes"), "Oui")
        L10n.isFrench = false
        XCTAssertEqual(L10n.tr("Oui", "Yes"), "Yes")
    }
}

final class RecentGamesTests: XCTestCase {
    func testRecordDedupesAndLimits() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)"))
        let recents = RecentGames(defaults: defaults)
        for i in 0..<7 {
            recents.record(name: "Game \(i)", titleID: nil, romPath: "/g/\(i).xci")
        }
        recents.record(name: "Game 4", titleID: nil, romPath: "/g/4.xci")
        XCTAssertEqual(recents.entries.map(\.name), ["Game 4", "Game 6", "Game 5", "Game 3", "Game 2"])
        XCTAssertEqual(RecentGames(defaults: defaults).entries, recents.entries, "persisted")
    }
}

final class GameSettingsTests: XCTestCase {
    private func makeDefaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)"))
    }

    func testHiddenAndCustomNamePersistByFileName() throws {
        let defaults = try makeDefaults()
        let settings = GameSettings(defaults: defaults)
        XCTAssertFalse(settings.isHidden("/a/Mario.xcz"))

        settings.setHidden(true, for: "/a/Mario.xcz")
        settings.setCustomName("  Mario Bros  ", for: "/a/Mario.xcz")
        let reloaded = GameSettings(defaults: defaults)
        XCTAssertTrue(reloaded.isHidden("/moved/folder/Mario.xcz"), "keyed by file name")
        XCTAssertEqual(reloaded.displayName(for: "/a/Mario.xcz", detected: "x"), "Mario Bros")
    }

    func testEmptyNameAndDefaultsClearEntry() throws {
        let settings = GameSettings(defaults: try makeDefaults())
        settings.setCustomName("Zelda", for: "/z.nsp")
        settings.setCustomName("   ", for: "/z.nsp")
        XCTAssertEqual(settings.displayName(for: "/z.nsp", detected: "Detected"), "Detected")
        XCTAssertTrue(settings.prefs.isEmpty, "default prefs are not stored")
    }

    func testShowOnDiscordDefaultsToTrue() throws {
        XCTAssertTrue(GameSettings(defaults: try makeDefaults()).showOnDiscord)
    }
}

final class GameLibraryTests: XCTestCase {
    func testScanFindsROMsSortedWithTitleIDs() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sub = root.appendingPathComponent("Nintendo")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for file in ["Zelda [0100F2C0115B6000].nsp", "Nintendo/Mario.xcz", "notes.txt", ".hidden.xci"] {
            FileManager.default.createFile(atPath: root.appendingPathComponent(file).path, contents: Data())
        }

        let games = GameLibrary.scan(root, known: ["Mario.xcz": "0100EA80032EA000"])
        XCTAssertEqual(games.map(\.name), ["Mario", "Zelda"])
        XCTAssertEqual(games.map(\.titleID), ["0100EA80032EA000", "0100F2C0115B6000"])
    }
}

final class TitleMatchingTests: XCTestCase {
    func testNormalize() {
        XCTAssertEqual(GameDetector.normalize("Super Mario Bros.™ Wonder"), "supermariobroswonder")
        XCTAssertEqual(GameDetector.normalize("Pokémon Legends: Arceus"), "pokemonlegendsarceus")
    }

    func testScanMatchesByTitle() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        FileManager.default.createFile(atPath: root.appendingPathComponent("Super Mario Bros. Wonder.xcz").path, contents: Data())

        let games = GameLibrary.scan(root, titles: ["supermariobroswonder": "010015100B514000"])
        XCTAssertEqual(games.first?.titleID, "010015100B514000")
    }

    func testRememberTitleID() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)"))
        GameSettings(defaults: defaults).rememberTitleID("0100AAA", for: "/x/Game.xci")
        XCTAssertEqual(GameSettings(defaults: defaults).knownTitleIDs["Game.xci"], "0100AAA")
    }
}

final class PresenceLimitsTests: XCTestCase {
    func testFieldLengths() {
        XCTAssertEqual(Presence.field("A").count, 2, "Discord needs 2 characters")
        XCTAssertEqual(Presence.field("  Zelda  "), "Zelda")
        let long = Presence.field(String(repeating: "x", count: 200))
        XCTAssertEqual(long.count, 128)
        XCTAssertTrue(long.hasSuffix("…"))
        XCTAssertEqual(Presence.field("Un très long libellé de bouton ici", max: 32).count, 32)
    }

    func testInvalidButtonsAndImageAreDropped() {
        let p = Presence(details: "Mario", image: "not a url", buttons: [
            ("Ok", "https://example.com"), ("", "https://example.com"), ("Bad", "ftp://x"), ("Two", "http://b.c"),
        ])
        let a = p.activity
        XCTAssertNil(a["assets"])
        let buttons = a["buttons"] as? [[String: String]]
        XCTAssertEqual(buttons?.map { $0["label"] }, ["Ok", "Two"])
    }

    func testDiscordErrorReply() {
        XCTAssertEqual(DiscordIPC.reply(from: ["evt": NSNull(), "cmd": "SET_ACTIVITY"]), .ok)
        let error: [String: Any] = ["evt": "ERROR", "data": ["code": NSNumber(value: 4000), "message": "child \"activity\" fails"]]
        XCTAssertEqual(DiscordIPC.reply(from: error), .rejected("child \"activity\" fails (4000)"))
    }
}

final class DiskCacheTests: XCTestCase {
    func testStorePersistsAndExpires() {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let now = Date()
        let store = DiskStore(file: file)
        XCTAssertFalse(store.lookup("A").hit)
        store.set("https://x/a.png", for: "A", now: now)
        store.set(nil, for: "B", now: now)

        let reloaded = DiskStore(file: file)
        XCTAssertEqual(reloaded.lookup("A", now: now).value, "https://x/a.png")
        XCTAssertTrue(reloaded.lookup("B", now: now).hit, "a known miss is a hit")
        XCTAssertNil(reloaded.lookup("B", now: now).value)
        XCTAssertFalse(reloaded.lookup("B", now: now.addingTimeInterval(DiskStore.missingLifetime + 1)).hit, "misses expire first")
        XCTAssertTrue(reloaded.lookup("A", now: now.addingTimeInterval(DiskStore.missingLifetime + 1)).hit)
    }

    func testCoverResolverUsesStore() {
        let store = DiskStore(file: nil)
        store.set("https://x/cover.png", for: "0100EA80032EA000")
        XCTAssertEqual(CoverResolver(store: store).cover(for: "0100EA80032EA000"), "https://x/cover.png")
    }

    func testImageFileNameIsStable() {
        XCTAssertEqual(ImageCache.fileName(for: "a"), ImageCache.fileName(for: "a"))
        XCTAssertNotEqual(ImageCache.fileName(for: "a"), ImageCache.fileName(for: "b"))
        XCTAssertEqual(ImageCache.fileName(for: "a").count, 64)
    }
}

final class LogTests: XCTestCase {
    func testKeepsRecentLinesWithoutRepeats() {
        let log = Log()
        log.add("a")
        log.add("a")
        log.add("b")
        XCTAssertEqual(log.recent.count, 2)
        XCTAssertTrue(log.recent[1].hasSuffix("  b"))
        for i in 0..<(Log.limit + 10) { log.add("line \(i)") }
        XCTAssertEqual(log.recent.count, Log.limit)
    }
}

final class IdleTests: XCTestCase {
    func testIsIdle() {
        XCTAssertFalse(IdleMonitor.isIdle(idleTime: 3600, afterMinutes: 0), "0 = never")
        XCTAssertFalse(IdleMonitor.isIdle(idleTime: 299, afterMinutes: 5))
        XCTAssertTrue(IdleMonitor.isIdle(idleTime: 300, afterMinutes: 5))
    }

    func testIdleDefaultsTo15Minutes() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)"))
        XCTAssertEqual(GameSettings(defaults: defaults).idleMinutes, 15)
    }
}

final class PresenceTemplateTests: XCTestCase {
    func testRenderDropsPartsWithoutValue() {
        XCTAssertEqual(PresenceTemplate.render("Sur Astris · {played} jouées", values: ["played": "12 h"]), "Sur Astris · 12 h jouées")
        XCTAssertEqual(PresenceTemplate.render("Sur Astris · {played} jouées", values: ["played": nil]), "Sur Astris")
        XCTAssertEqual(PresenceTemplate.render("{game} · {version}", values: ["game": "Zelda", "version": ""]), "Zelda")
        XCTAssertNil(PresenceTemplate.render("{played}", values: ["played": nil]))
        XCTAssertEqual(PresenceTemplate.render("Hello {unknown}", values: [:]), "Hello {unknown}", "unknown tokens stay as typed")
    }

    func testCustomButtonNeedsLabelAndWebURL() throws {
        let settings = GameSettings(defaults: try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)")))
        XCTAssertTrue(settings.showEShopButton)
        settings.customButtonLabel = "Mon stream"
        XCTAssertNil(settings.customButton)
        settings.customButtonURL = "twitch.tv/moi"
        XCTAssertNil(settings.customButton)
        settings.customButtonURL = "https://twitch.tv/moi"
        XCTAssertEqual(settings.customButton?.url, "https://twitch.tv/moi")
    }
}

final class PlayHistoryTests: XCTestCase {
    func testSessionsSplitOnGapsAndGameChanges() {
        let history = PlayHistory(file: nil)
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        for i in 0...20 { history.update(name: "Mario", titleID: "0100A", romPath: "/g/Mario.xci", now: t0 + Double(i * 3)) }
        XCTAssertEqual(history.sessions.count, 1)
        XCTAssertEqual(history.sessions[0].duration, 60)

        history.update(name: "Mario", titleID: "0100A", romPath: "/g/Mario.xci", now: t0 + 600)
        XCTAssertEqual(history.sessions.count, 2, "long gap: new session")
        history.update(name: "Zelda", titleID: nil, romPath: "/g/Zelda.nsp", now: t0 + 603)
        XCTAssertEqual(history.sessions.count, 3)
        history.update(name: nil, titleID: nil, romPath: nil, now: t0 + 606)
        history.update(name: "Zelda", titleID: nil, romPath: "/g/Zelda.nsp", now: t0 + 609)
        XCTAssertEqual(history.sessions.count, 4, "idle or stop closes the session")
    }

    func testTotalsAndPersistence() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let history = PlayHistory(file: file)
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        history.update(name: "Mario", titleID: "0100A", romPath: "/g/Mario.xci", now: t0)
        history.update(name: "Mario", titleID: "0100A", romPath: "/g/Mario.xci", now: t0 + 50)
        history.update(name: "Zelda", titleID: nil, romPath: "/g/Zelda.nsp", now: t0 + 100)
        history.update(name: "Zelda", titleID: nil, romPath: "/g/Zelda.nsp", now: t0 + 130)
        history.save()

        let reloaded = PlayHistory(file: file)
        XCTAssertEqual(reloaded.sessions.count, 2)
        XCTAssertEqual(reloaded.total(since: .distantPast), 80)
        XCTAssertEqual(reloaded.total(since: t0 + 25), 55, "sessions are cut at the date")
        let rows = reloaded.totals(recentSince: t0 + 110)
        XCTAssertEqual(rows.map(\.name), ["Mario", "Zelda"])
        XCTAssertEqual(rows.map(\.recent), [0, 20])
    }

    func testFormat() {
        XCTAssertEqual(PlayHistory.format(30), "0 min")
        XCTAssertEqual(PlayHistory.format(45 * 60), "45 min")
        XCTAssertEqual(PlayHistory.format(3 * 3600 + 5 * 60), "3 h 05")
    }
}

final class VersionTests: XCTestCase {
    func testVersionInFileName() {
        L10n.isFrench = false
        XCTAssertEqual(GameDetector.version(in: "Zelda [0100F2C0115B6000][v1.2.0]"), "1.2.0")
        XCTAssertEqual(GameDetector.version(in: "Zelda v1.0.1 (EU)"), "1.0.1")
        XCTAssertEqual(GameDetector.version(in: "Zelda [0100F2C0115B6800][v196608]"), "update 3")
        XCTAssertNil(GameDetector.version(in: "Zelda [0100F2C0115B6000][v0]"))
        XCTAssertNil(GameDetector.version(in: "Zelda Remastered"))
        XCTAssertNil(GameDetector.version(in: "Mariov2"))
    }

    func testTitleKinds() {
        XCTAssertEqual(GameDetector.kind(of: "0100F2C0115B6000"), .base)
        XCTAssertEqual(GameDetector.kind(of: "0100F2C0115B6800"), .update)
        XCTAssertEqual(GameDetector.kind(of: "0100F2C0115B7001"), .dlc)
        XCTAssertNil(GameDetector.kind(of: "nope"))
        XCTAssertEqual(GameDetector.baseTitleID(of: "0100F2C0115B6800"), "0100F2C0115B6000")
        XCTAssertEqual(GameDetector.baseTitleID(of: "0100F2C0115B7001"), "0100F2C0115B6000")
        XCTAssertEqual(GameDetector.baseTitleID(of: "0100F2C0115B6000"), "0100F2C0115B6000")
    }

    func testSmallImageNeedsWebURL() {
        var p = Presence(details: "Zelda", image: "https://x/c.png", smallImage: "https://x/l.png", smallText: "Astris · v1.2.0")
        var assets = p.activity["assets"] as? [String: Any]
        XCTAssertEqual(assets?["small_text"] as? String, "Astris · v1.2.0")
        p.smallImage = nil
        assets = p.activity["assets"] as? [String: Any]
        XCTAssertNil(assets?["small_text"])
    }
}
