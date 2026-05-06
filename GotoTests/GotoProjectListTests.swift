import XCTest

final class GotoProjectListTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("GotoProjectListTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        GotoSettings.recentProjectsURLOverride = tempRoot.appendingPathComponent(".goto_recent")
        GotoSettings.cliConfigURLOverride = tempRoot.appendingPathComponent(".goto_config")
    }

    override func tearDownWithError() throws {
        GotoSettings.recentProjectsURLOverride = nil
        GotoSettings.cliConfigURLOverride = nil
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        try super.tearDownWithError()
    }

    func testSortOptionIdentifierRoundTripsAndAdvances() {
        let option = GotoSortOption.createdAtDescending

        XCTAssertEqual(GotoSortOption(identifier: option.identifier), option)
        XCTAssertEqual(GotoSortOption.nameAscending.next, .nameDescending)
        XCTAssertEqual(GotoSortOption.createdAtDescending.next, .nameAscending)
        XCTAssertNil(GotoSortOption(identifier: "invalid"))
    }

    func testOrderedProjectsReturnsRecentsFirstWithBoundary() throws {
        let boop = "/tmp/inchan/Boop2"
        let labs = "/tmp/workspace/labs"
        let zed = "/tmp/workspace/zed"
        try "\(boop)\n/missing/project\n\(boop)\n".write(
            to: GotoSettings.recentProjectsURL,
            atomically: true,
            encoding: .utf8
        )

        var config = GotoCLIConfig()
        config.parentSortDirection = .ascending
        config.projectSortDirection = .ascending

        let ordered = GotoProjectList.orderedProjects([zed, labs, boop], config: config)

        XCTAssertEqual(ordered.recentCount, 1)
        XCTAssertEqual(ordered.displayProjects, [boop, labs, zed])
    }
}
