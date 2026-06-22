import XCTest

final class GotoUpdateServiceTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("GotoUpdateServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        GotoProjectStore.storeURLOverride = tempRoot.appendingPathComponent(".goto")
    }

    override func tearDownWithError() throws {
        GotoProjectStore.storeURLOverride = nil
        if let tempRoot { try? FileManager.default.removeItem(at: tempRoot) }
        try super.tearDownWithError()
    }

    func testCompareSemVerHandlesVPrefixAndFields() {
        XCTAssertEqual(GotoUpdateService.compareSemVer("v0.0.28", "0.0.28"), .orderedSame)
        XCTAssertEqual(GotoUpdateService.compareSemVer("0.0.28", "0.0.29"), .orderedAscending)
        XCTAssertEqual(GotoUpdateService.compareSemVer("0.1.0", "0.0.99"), .orderedDescending)
        XCTAssertEqual(GotoUpdateService.compareSemVer("1.0.0", "0.9.9"), .orderedDescending)
        XCTAssertEqual(GotoUpdateService.compareSemVer("0.0.1", "0.0.1"), .orderedSame)
    }

    func testIsUpdateAvailableGuardsDevAndComparesCorrectly() {
        XCTAssertFalse(GotoUpdateService.isUpdateAvailable(current: "0.0.0", latest: "v9.9.9"))
        XCTAssertTrue(GotoUpdateService.isUpdateAvailable(current: "0.0.28", latest: "v0.0.29"))
        XCTAssertFalse(GotoUpdateService.isUpdateAvailable(current: "0.0.29", latest: "v0.0.29"))
        XCTAssertFalse(GotoUpdateService.isUpdateAvailable(current: "0.0.30", latest: "v0.0.29"))
    }

    func testCacheRoundTripAndCorruptReturnsNil() throws {
        XCTAssertNil(GotoUpdateService.loadCache())
        let cache = GotoUpdateCache(lastCheckedAt: Date(timeIntervalSince1970: 1_000_000), latestTag: "v0.0.28")
        GotoUpdateService.saveCache(cache)
        XCTAssertEqual(GotoUpdateService.loadCache(), cache)
        try Data("not json".utf8).write(to: GotoUpdateService.cacheStoreURL, options: .atomic)
        XCTAssertNil(GotoUpdateService.loadCache())
    }

    func testShouldCheckRespectsTTL() {
        let base = Date(timeIntervalSince1970: 2_000_000)
        XCTAssertTrue(GotoUpdateService.shouldCheck(now: base, cache: nil, ttl: 86_400))
        let recent = GotoUpdateCache(lastCheckedAt: base, latestTag: "v0.0.28")
        XCTAssertFalse(GotoUpdateService.shouldCheck(now: base.addingTimeInterval(86_399), cache: recent, ttl: 86_400))
        XCTAssertTrue(GotoUpdateService.shouldCheck(now: base.addingTimeInterval(86_401), cache: recent, ttl: 86_400))
    }

    func testCacheStoreURLIsSiblingOfStore() {
        XCTAssertEqual(GotoUpdateService.cacheStoreURL.lastPathComponent, ".goto_update_check")
        XCTAssertEqual(
            GotoUpdateService.cacheStoreURL.deletingLastPathComponent().path,
            GotoProjectStore.storeURL.deletingLastPathComponent().path
        )
    }
}
