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
