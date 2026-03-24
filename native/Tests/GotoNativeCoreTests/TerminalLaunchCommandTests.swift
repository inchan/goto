import Foundation
import XCTest

@testable import GotoNativeCore

final class TerminalLaunchCommandTests: XCTestCase {
    func testDryRunPrintsResolvedDirectoryWithoutLaunching() throws {
        let directory = try temporaryDirectory()
        let launcher = StubTerminalLauncher()
        let command = TerminalLaunchCommand(launcher: launcher)

        let result = command.run(arguments: ["GotoNativeLaunch", "--dry-run", directory.path])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, directory.resolvingSymlinksInPath().standardizedFileURL.path)
        XCTAssertEqual(result.stderr, "")
        XCTAssertEqual(launcher.requests, [])
    }

    func testLaunchUsesFinderSurface() throws {
        let directory = try temporaryDirectory()
        let launcher = StubTerminalLauncher()
        let command = TerminalLaunchCommand(launcher: launcher)

        let result = command.run(arguments: ["GotoNativeLaunch", directory.path])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(
            launcher.requests,
            [
                TerminalLaunchRequest(
                    directory: ValidatedDirectory(path: directory.path),
                    surface: .finder
                )
            ]
        )
    }

    func testMissingPathReturnsUserFacingError() {
        let command = TerminalLaunchCommand(launcher: StubTerminalLauncher())

        let result = command.run(arguments: ["GotoNativeLaunch", "/tmp/does-not-exist-\(UUID().uuidString)"])

        XCTAssertEqual(result.exitCode, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Folder Not Found"))
    }

    func testPermissionFailureReturnsUserFacingError() throws {
        let directory = try temporaryDirectory()
        let command = TerminalLaunchCommand(
            launcher: StubTerminalLauncher(error: .permissionDenied)
        )

        let result = command.run(arguments: ["GotoNativeLaunch", directory.path])

        XCTAssertEqual(result.exitCode, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Terminal Permission Required"))
    }

    func testUsageFailureReturnsExit64() {
        let command = TerminalLaunchCommand(launcher: StubTerminalLauncher())

        let result = command.run(arguments: ["GotoNativeLaunch"])

        XCTAssertEqual(result.exitCode, 64)
        XCTAssertEqual(result.stdout, "")
        XCTAssertEqual(result.stderr, "Usage: GotoNativeLaunch [--dry-run] <folder-path>")
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private final class StubTerminalLauncher: TerminalLaunching {
    private let error: TerminalLaunchError?
    private(set) var requests: [TerminalLaunchRequest] = []

    init(error: TerminalLaunchError? = nil) {
        self.error = error
    }

    func launch(_ request: TerminalLaunchRequest) throws -> AppleScriptExecutionResult {
        requests.append(request)

        if let error {
            throw error
        }

        return AppleScriptExecutionResult(exitCode: 0, stdout: "", stderr: "")
    }
}
