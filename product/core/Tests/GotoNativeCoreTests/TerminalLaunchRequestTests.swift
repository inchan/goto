import XCTest

@testable import GotoNativeCore

final class TerminalLaunchRequestTests: XCTestCase {
    func testRequestExposesDirectoryMetadata() {
        let request = TerminalLaunchRequest(
            directory: ValidatedDirectory(path: "/tmp/demo project", name: "demo project")
        )

        XCTAssertEqual(request.directoryPath, "/tmp/demo project")
        XCTAssertEqual(request.displayName, "demo project")
    }

    func testBuilderProducesShellCommandForRequest() {
        let builder = TerminalScriptBuilder()
        XCTAssertEqual(builder.shellCommand(forDirectory: "/tmp/demo project"), "cd -- '/tmp/demo project'")
    }

    func testBuilderProducesAppleScriptForNonAsciiPath() {
        let builder = TerminalScriptBuilder()
        XCTAssertTrue(builder.appleScript(forDirectory: "/tmp/프로젝트").contains("do script \"cd -- '/tmp/프로젝트'\""))
    }
}
