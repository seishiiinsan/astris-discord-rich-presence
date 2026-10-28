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

final class CustomCoverTests: XCTestCase {
    func testOldPrefsStillDecode() throws {
        let old = Data(#"{"Mario.xcz": {"hidden": true}}"#.utf8)
        let prefs = try JSONDecoder().decode([String: GameSettings.GamePrefs].self, from: old)
        XCTAssertEqual(prefs["Mario.xcz"]?.hidden, true)
        XCTAssertNil(prefs["Mario.xcz"]?.customCover)
    }

    func testOnlyWebCoversGoToDiscord() throws {
        let settings = GameSettings(defaults: try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)")))
        settings.setCustomCover("https://x/cover.png", for: "/g/Homebrew.nro")
        XCTAssertEqual(settings.discordCover(for: "/moved/Homebrew.nro"), "https://x/cover.png")
        settings.setCustomCover("file:///tmp/cover.png", for: "/g/Homebrew.nro")
        XCTAssertNil(settings.discordCover(for: "/g/Homebrew.nro"))
        XCTAssertEqual(settings.prefs(for: "/g/Homebrew.nro").customCover, "file:///tmp/cover.png")
        settings.setCustomCover("  ", for: "/g/Homebrew.nro")
        XCTAssertTrue(settings.prefs.isEmpty)
    }
}

final class FavoritesTests: XCTestCase {
    func testFavoritesPersistInOrder() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)"))
        let settings = GameSettings(defaults: defaults)
        settings.setFavorite(true, for: "/g/Zelda.nsp")
        settings.setFavorite(true, for: "/g/Mario.xci")
        settings.setFavorite(true, for: "/g/Zelda.nsp")
        XCTAssertEqual(settings.favorites, ["/g/Mario.xci", "/g/Zelda.nsp"])
        settings.setFavorite(false, for: "/g/Mario.xci")
        XCTAssertEqual(GameSettings(defaults: defaults).favorites, ["/g/Zelda.nsp"])
        XCTAssertTrue(settings.isFavorite("/g/Zelda.nsp"))
    }
}

final class HotKeysTests: XCTestCase {
    func testDefaultsAndKeys() throws {
        let settings = GameSettings(defaults: try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)")))
        XCTAssertTrue(settings.hotKeysEnabled)
        XCTAssertEqual(HotKeys.keyEquivalent(.toggleDiscord), "d")
        XCTAssertEqual(HotKeys.keyEquivalent(.toggleHideGame), "h")
        XCTAssertNotEqual(HotKeys.Action.toggleDiscord.keyCode, HotKeys.Action.toggleHideGame.keyCode)
    }
}

final class LanguageTests: XCTestCase {
    func testResolve() {
        XCTAssertTrue(L10n.resolve(.system, preferred: ["fr-FR", "en"]))
        XCTAssertFalse(L10n.resolve(.system, preferred: ["en-US"]))
        XCTAssertFalse(L10n.resolve(.system, preferred: []))
        XCTAssertTrue(L10n.resolve(.french, preferred: ["en-US"]))
        XCTAssertFalse(L10n.resolve(.english, preferred: ["fr-FR"]))
    }

    func testLanguageSettingPersists() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)"))
        XCTAssertEqual(GameSettings(defaults: defaults).language, .system)
        GameSettings(defaults: defaults).language = .english
        XCTAssertEqual(GameSettings(defaults: defaults).language, .english)
    }
}

final class AstrisConfigTests: XCTestCase {
    func testParse() throws {
        let json = #"{"game_dirs": ["/Volumes/Switch", ""], "docked_mode": false, "multiplayer_mode": "LdnMitm"}"#
        let config = try XCTUnwrap(AstrisConfig.parse(Data(json.utf8)))
        XCTAssertEqual(config.gameDirectories.map(\.path), ["/Volumes/Switch"])
        XCTAssertEqual(config.docked, false)
        XCTAssertTrue(config.multiplayer)
    }

    func testMultiplayerVariants() throws {
        XCTAssertFalse(try XCTUnwrap(AstrisConfig.parse(Data(#"{"multiplayer_mode": "Disabled"}"#.utf8))).multiplayer)
        XCTAssertFalse(try XCTUnwrap(AstrisConfig.parse(Data(#"{"multiplayer_mode": 0}"#.utf8))).multiplayer)
        XCTAssertTrue(try XCTUnwrap(AstrisConfig.parse(Data(#"{"multiplayer_mode": 1}"#.utf8))).multiplayer)
        let empty = try XCTUnwrap(AstrisConfig.parse(Data("{}".utf8)))
        XCTAssertNil(empty.docked)
        XCTAssertFalse(empty.multiplayer)
        XCTAssertNil(AstrisConfig.parse(Data("nope".utf8)))
    }
}

final class ModeTemplateTests: XCTestCase {
    func testMultiOnlyWhenOn() {
        L10n.isFrench = true
        let template = PresenceTemplate.defaultState
        XCTAssertEqual(PresenceTemplate.render(template, values: ["played": "3 h", "multi": nil]), "Sur Astris · 3 h jouées")
        XCTAssertEqual(PresenceTemplate.render(template, values: ["played": nil, "multi": "Multijoueur local"]), "Sur Astris · Multijoueur local")
    }
}

final class AstrisFavoritesTests: XCTestCase {
    func testGameInfo() {
        let info = GameDetector.gameInfo(["favorite": true, "timespan_played": "02:00:00"])
        XCTAssertTrue(info.favorite)
        XCTAssertEqual(info.played, 7200)
        XCTAssertFalse(GameDetector.gameInfo([:]).favorite)
    }

    func testImportOncePerTitle() throws {
        let settings = GameSettings(defaults: try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)")))
        let games = [
            GameLibrary.Game(url: URL(fileURLWithPath: "/g/Zelda.nsp"), name: "Zelda", titleID: "0100F2C0115B6000"),
            GameLibrary.Game(url: URL(fileURLWithPath: "/g/Mario.xci"), name: "Mario", titleID: "0100EA80032EA000"),
        ]
        XCTAssertEqual(settings.importAstrisFavorites(games, astrisFavorites: ["0100F2C0115B6000"]), 1)
        XCTAssertEqual(settings.favorites, ["/g/Zelda.nsp"])
        settings.setFavorite(false, for: "/g/Zelda.nsp")
        XCTAssertEqual(settings.importAstrisFavorites(games, astrisFavorites: ["0100F2C0115B6000"]), 0, "un-starred stays un-starred")
        XCTAssertTrue(settings.favorites.isEmpty)
    }
}

final class PerGameTemplateTests: XCTestCase {
    func testGameLinesOverrideGlobalOnes() throws {
        let settings = GameSettings(defaults: try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)")))
        settings.detailsTemplate = "{game}"
        settings.stateTemplate = "Global"
        settings.setTemplates(details: "Run any%", state: "  ", for: "/g/Mario.xci")
        let t = settings.templates(for: "/g/Mario.xci")
        XCTAssertEqual(t.details, "Run any%")
        XCTAssertEqual(t.state, "Global", "empty falls back")
        XCTAssertEqual(settings.templates(for: "/g/Zelda.nsp").details, "{game}")
        XCTAssertEqual(settings.templates(for: nil).state, "Global")
    }
}

final class StreamerModeTests: XCTestCase {
    func testStreamerModeHidesChosenParts() throws {
        let settings = GameSettings(defaults: try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)")))
        XCTAssertFalse(settings.hidesPlayedTime("/g/Mario.xci"))
        XCTAssertFalse(settings.hidesEShop)
        settings.streamerMode = true
        XCTAssertTrue(settings.hidesPlayedTime("/g/Mario.xci"))
        XCTAssertTrue(settings.hidesEShop)
        XCTAssertFalse(settings.hidesCover, "covers stay by default")
        settings.streamerHidesPlayed = false
        XCTAssertFalse(settings.hidesPlayedTime("/g/Mario.xci"))
        settings.setHidePlayedTime(true, for: "/g/Mario.xci")
        XCTAssertTrue(settings.hidesPlayedTime("/g/Mario.xci"), "per-game setting")
    }
}

final class URLCommandTests: XCTestCase {
    private func parse(_ s: String) -> URLCommand? { URLCommand.parse(URL(string: s)!) }

    func testParse() {
        XCTAssertEqual(parse("astrisrpc://toggle"), .toggle)
        XCTAssertEqual(parse("astrisrpc://on"), .show)
        XCTAssertEqual(parse("ASTRISRPC://off"), .hide)
        XCTAssertEqual(parse("astrisrpc:hide-game"), .hideGame)
        XCTAssertEqual(parse("astrisrpc://streamer"), .streamer(nil))
        XCTAssertEqual(parse("astrisrpc://streamer?on=1"), .streamer(true))
        XCTAssertEqual(parse("astrisrpc://launch?game=Zelda%20TOTK"), .launch("Zelda TOTK"))
        XCTAssertNil(parse("astrisrpc://launch"))
        XCTAssertNil(parse("astrisrpc://nope"))
        XCTAssertNil(parse("https://toggle"))
    }

    func testMatch() {
        let games = [(path: "/g/a.nsp", name: "The Legend of Zelda: Tears of the Kingdom"),
                     (path: "/g/b.nsp", name: "Zelda"),
                     (path: "/g/c.xci", name: "Super Mario Odyssey")]
        XCTAssertEqual(URLCommand.match("zelda", in: games), "/g/b.nsp", "exact first")
        XCTAssertEqual(URLCommand.match("tears of the kingdom", in: games), "/g/a.nsp")
        XCTAssertEqual(URLCommand.match("Mario", in: games), "/g/c.xci")
        XCTAssertNil(URLCommand.match("Kirby", in: games))
    }
}

final class NotifierTests: XCTestCase {
    private func calendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }

    func testSummaryDueSundayEveningOncePerWeek() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)"))
        let notifier = Notifier(defaults: defaults)
        let cal = calendar()
        let sundayEvening = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 20)))
        let sundayNoon = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12)))
        let monday = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 20)))
        XCTAssertFalse(notifier.isSummaryDue(now: sundayNoon, calendar: cal))
        XCTAssertFalse(notifier.isSummaryDue(now: monday, calendar: cal))
        XCTAssertTrue(notifier.isSummaryDue(now: sundayEvening, calendar: cal))
        notifier.markSummarySent(now: sundayEvening, calendar: cal)
        XCTAssertFalse(notifier.isSummaryDue(now: sundayEvening.addingTimeInterval(3600), calendar: cal))
        XCTAssertTrue(notifier.isSummaryDue(now: sundayEvening.addingTimeInterval(7 * 86400), calendar: cal))
    }

    func testWeeklySummaryText() {
        L10n.isFrench = true
        let now = Date()
        let rows = [
            PlayHistory.GameTotal(rom: "z.nsp", name: "Zelda", titleID: nil, total: 99999, recent: 5 * 3600 + 600, lastPlayed: now),
            PlayHistory.GameTotal(rom: "m.xci", name: "Mario", titleID: nil, total: 9999, recent: 3 * 3600, lastPlayed: now),
            PlayHistory.GameTotal(rom: "k.xci", name: "Kirby", titleID: nil, total: 30, recent: 30, lastPlayed: now),
        ]
        XCTAssertEqual(Notifier.weeklySummary(rows, name: \.name), "8 h 10 cette semaine sur 2 jeux, surtout Zelda (5 h 10).")
        XCTAssertEqual(Notifier.weeklySummary(Array(rows.suffix(2)), name: \.name), "3 h 00 cette semaine, sur Mario.")
        XCTAssertNil(Notifier.weeklySummary([rows[2]], name: \.name))
    }
}

final class StatsExtrasTests: XCTestCase {
    func testBucketsSplitSessions() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let history = PlayHistory(file: nil)
        let midnight = cal.date(from: DateComponents(year: 2026, month: 10, day: 28))!
        // 23:30 → 00:30: half on each day.
        history.update(name: "Zelda", titleID: nil, romPath: "/z.nsp", now: midnight - 1800)
        stride(from: -1800.0, through: 1800, by: 30).forEach {
            history.update(name: "Zelda", titleID: nil, romPath: "/z.nsp", now: midnight + $0)
        }
        let days = PlayHistory.days(2, now: midnight + 3600, calendar: cal)
        XCTAssertEqual(days.first?.start, midnight - 86400)
        XCTAssertEqual(history.totals(in: days).map(\.seconds), [1800, 1800])
        XCTAssertEqual(PlayHistory.weeks(4, now: midnight, calendar: cal).count, 4)
    }

    func testCSV() {
        let history = PlayHistory(file: nil)
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        history.update(name: "Zelda, TOTK", titleID: "0100F2C0115B6000", romPath: "/z.nsp", now: t0)
        history.update(name: "Zelda, TOTK", titleID: "0100F2C0115B6000", romPath: "/z.nsp", now: t0 + 60)
        let lines = history.csv { $0.name }.split(separator: "\n")
        XCTAssertEqual(lines.first, "game,file,title_id,start,end,minutes")
        XCTAssertTrue(lines[1].hasPrefix("\"Zelda, TOTK\",z.nsp,0100F2C0115B6000,"))
        XCTAssertTrue(lines[1].hasSuffix(",1"))
    }
}

final class SteamGridDBTests: XCTestCase {
    func testURLsAndParsing() {
        XCTAssertEqual(SteamGridDB.searchURL("Zelda: TOTK/2")?.absoluteString,
                       "https://www.steamgriddb.com/api/v2/search/autocomplete/Zelda:%20TOTK%2F2")
        XCTAssertEqual(SteamGridDB.gridsURL(gameID: 42)?.absoluteString,
                       "https://www.steamgriddb.com/api/v2/grids/game/42?dimensions=512x512,1024x1024&types=static")
        let body = Data(#"{"success": true, "data": [{"id": 42, "name": "Zelda"}]}"#.utf8)
        XCTAssertEqual((SteamGridDB.data(body)?.first?["id"] as? NSNumber)?.intValue, 42)
        XCTAssertNil(SteamGridDB.data(Data(#"{"success": false}"#.utf8)))
    }

    func testNoKeyNoLookup() {
        let sgdb = SteamGridDB(store: nil)
        XCTAssertNil(sgdb.cover(forName: "Zelda", apiKey: nil))
        XCTAssertNil(sgdb.cover(forName: "Zelda", apiKey: ""))
    }

    func testStoredCoverAndOrder() throws {
        let store = DiskStore(file: nil)
        store.set("https://sgdb/zelda.png", for: "zelda")
        XCTAssertEqual(SteamGridDB(store: store).cover(forName: "Zelda", apiKey: "k"), "https://sgdb/zelda.png")

        let settings = GameSettings(defaults: try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)")))
        XCTAssertEqual(settings.pickCover(switchArt: { "switch" }, steamGridDB: { "sgdb" }), "switch", "no key: Switch art only")
        settings.steamGridDBKey = "k"
        XCTAssertEqual(settings.pickCover(switchArt: { nil }, steamGridDB: { "sgdb" }), "sgdb", "fallback")
        XCTAssertEqual(settings.pickCover(switchArt: { "switch" }, steamGridDB: { "sgdb" }), "switch")
        settings.preferSteamGridDB = true
        XCTAssertEqual(settings.pickCover(switchArt: { "switch" }, steamGridDB: { "sgdb" }), "sgdb")
    }
}

final class MenuBarTimerTests: XCTestCase {
    func testClockAndCurrentSession() {
        XCTAssertEqual(PlayHistory.clock(30), "0:00")
        XCTAssertEqual(PlayHistory.clock(5 * 60), "0:05")
        XCTAssertEqual(PlayHistory.clock(84 * 60), "1:24")
        let history = PlayHistory(file: nil)
        XCTAssertNil(history.currentSessionStart)
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        history.update(name: "Zelda", titleID: nil, romPath: "/z.nsp", now: t0)
        XCTAssertEqual(history.currentSessionStart, t0)
        history.update(name: nil, titleID: nil, romPath: nil, now: t0 + 3)
        XCTAssertNil(history.currentSessionStart)
    }
}

final class PlayRemindersTests: XCTestCase {
    func testBreak() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertFalse(PlayReminders.isBreakDue(sessionStart: start, now: start + 7000, everyMinutes: 0, lastReminder: nil), "off")
        XCTAssertFalse(PlayReminders.isBreakDue(sessionStart: start, now: start + 7100, everyMinutes: 120, lastReminder: nil))
        XCTAssertTrue(PlayReminders.isBreakDue(sessionStart: start, now: start + 7200, everyMinutes: 120, lastReminder: nil))
        XCTAssertFalse(PlayReminders.isBreakDue(sessionStart: start, now: start + 8000, everyMinutes: 120, lastReminder: start + 7200))
        XCTAssertTrue(PlayReminders.isBreakDue(sessionStart: start, now: start + 14400, everyMinutes: 120, lastReminder: start + 7200))
        XCTAssertTrue(PlayReminders.isBreakDue(sessionStart: start, now: start + 7200, everyMinutes: 120, lastReminder: start - 10), "older session")
    }

    func testMilestonesAndRecord() {
        XCTAssertEqual(PlayReminders.crossedMilestone(from: 9.9 * 3600, to: 10 * 3600), 10)
        XCTAssertNil(PlayReminders.crossedMilestone(from: 10 * 3600, to: 11 * 3600))
        XCTAssertEqual(PlayReminders.crossedMilestone(from: 0, to: 30 * 3600), 25, "biggest one passed")
        XCTAssertTrue(PlayReminders.beatsRecord(current: 3601, previousCurrent: 3599, record: 3600))
        XCTAssertFalse(PlayReminders.beatsRecord(current: 3700, previousCurrent: 3650, record: 3600), "only once")
        XCTAssertFalse(PlayReminders.beatsRecord(current: 900, previousCurrent: 0, record: 600), "too short")
    }

    func testMilestoneSentOnce() throws {
        let settings = GameSettings(defaults: try XCTUnwrap(UserDefaults(suiteName: "AstrisRPCTests-\(UUID().uuidString)")))
        XCTAssertTrue(settings.markMilestone(10, for: "/g/Zelda.nsp"))
        XCTAssertFalse(settings.markMilestone(10, for: "/other/Zelda.nsp"))
        XCTAssertTrue(settings.markMilestone(25, for: "/g/Zelda.nsp"))
    }
}

final class ControllersTests: XCTestCase {
    func testLabelsAndLow() {
        let low = Controllers.Info(name: "Pro Controller", battery: 0.15, charging: false)
        XCTAssertEqual(Controllers.label(low), "Pro Controller · 15 %")
        XCTAssertTrue(Controllers.isLow(low))
        let charging = Controllers.Info(name: "DualSense", battery: 0.1, charging: true)
        XCTAssertEqual(Controllers.label(charging), "DualSense · 10 % ⚡︎")
        XCTAssertFalse(Controllers.isLow(charging))
        XCTAssertFalse(Controllers.isLow(Controllers.Info(name: "Joy-Con", battery: nil, charging: false)))
        XCTAssertEqual(Controllers.label(Controllers.Info(name: "Joy-Con", battery: nil, charging: false)), "Joy-Con")
    }
}
