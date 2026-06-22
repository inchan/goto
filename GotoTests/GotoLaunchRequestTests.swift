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

    func testParseRejectsWrongSchemeAndHost() {
        XCTAssertNil(GotoLaunchRequest.parse(url: URL(string: "gotolauncher://close?path=/tmp")!))
        XCTAssertNil(GotoLaunchRequest.parse(url: URL(string: "file:///tmp/project")!))
    }
}
