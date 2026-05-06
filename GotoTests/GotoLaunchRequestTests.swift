import XCTest

final class GotoLaunchRequestTests: XCTestCase {
    func testParseLauncherOpenURLWithAndWithoutPath() throws {
        let withPath = try XCTUnwrap(GotoLaunchRequest.url(path: "/tmp/project"))
        XCTAssertEqual(
            GotoLaunchRequest.parse(url: withPath),
            .openTerminal(path: "/tmp/project")
        )

        let withoutPath = try XCTUnwrap(GotoLaunchRequest.url(path: nil))
        XCTAssertEqual(
            GotoLaunchRequest.parse(url: withoutPath),
            .openTerminal(path: nil)
        )
    }

    func testParseWorktreesShowURLRequiresNonEmptyPath() throws {
        let valid = try XCTUnwrap(GotoLaunchRequest.worktreesURL(path: "/tmp/repo"))
        XCTAssertEqual(
            GotoLaunchRequest.parse(url: valid),
            .showWorktrees(path: "/tmp/repo")
        )

        XCTAssertNil(GotoLaunchRequest.worktreesURL(path: ""))
        XCTAssertNil(GotoLaunchRequest.parse(url: URL(string: "gotoworktree://show")!))
        XCTAssertNil(GotoLaunchRequest.parse(url: URL(string: "gotoworktree://show?path=")!))
    }

    func testParseRejectsWrongSchemeAndHost() {
        XCTAssertNil(GotoLaunchRequest.parse(url: URL(string: "gotolauncher://close?path=/tmp")!))
        XCTAssertNil(GotoLaunchRequest.parse(url: URL(string: "file:///tmp/project")!))
    }
}
