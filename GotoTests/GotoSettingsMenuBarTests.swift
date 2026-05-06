import XCTest

final class GotoSettingsMenuBarTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "GotoSettingsMenuBarTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        GotoSettings.userDefaults = defaults
    }

    override func tearDownWithError() throws {
        if let suiteName {
            defaults?.removePersistentDomain(forName: suiteName)
        }
        GotoSettings.userDefaults = .standard
        try super.tearDownWithError()
    }

    func testMenuBarEnabledDefaultsToFalseAndRoundTrips() {
        XCTAssertFalse(GotoSettings.isMenuBarEnabled())

        GotoSettings.setMenuBarEnabled(true)
        XCTAssertTrue(GotoSettings.isMenuBarEnabled())

        GotoSettings.setMenuBarEnabled(false)
        XCTAssertFalse(GotoSettings.isMenuBarEnabled())
    }

    func testMenuBarProjectGroupingDefaultsToFalseAndRoundTrips() {
        XCTAssertFalse(GotoSettings.isMenuBarProjectGroupingEnabled())

        GotoSettings.setMenuBarProjectGroupingEnabled(true)
        XCTAssertTrue(GotoSettings.isMenuBarProjectGroupingEnabled())

        GotoSettings.setMenuBarProjectGroupingEnabled(false)
        XCTAssertFalse(GotoSettings.isMenuBarProjectGroupingEnabled())
    }
}
