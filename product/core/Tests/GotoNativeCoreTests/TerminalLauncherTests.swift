import Foundation
import XCTest

@testable import GotoNativeCore

final class TerminalLauncherTests: XCTestCase {
    func testLaunchUsesOpenDirectlyForTerminalApp() throws {
        let opener = StubDirectoryOpener(
            result: AppleScriptExecutionResult(exitCode: 0, stdout: "", stderr: "")
        )
        let executor = StubAppleScriptExecutor(
            result: AppleScriptExecutionResult(exitCode: 0, stdout: "", stderr: "")
        )
        let launcher = TerminalLauncher(
            executor: executor,
            directoryOpener: opener,
            detector: FixedTerminalAppDetector(.terminal)
        )
        let request = TerminalLaunchRequest(
            directory: ValidatedDirectory(path: "/tmp/demo", name: "demo")
        )

        _ = try launcher.launch(request)

        XCTAssertTrue(executor.scripts.isEmpty)
        XCTAssertEqual(opener.calls.count, 1)
        XCTAssertEqual(opener.calls[0].arguments, ["-a", "Terminal", "/tmp/demo"])
    }

    func testLaunchUsesITermAppleScript() throws {
        let executor = StubAppleScriptExecutor(
            result: AppleScriptExecutionResult(exitCode: 0, stdout: "", stderr: "")
        )
        let launcher = TerminalLauncher(
            executor: executor,
            detector: FixedTerminalAppDetector(.iterm2)
        )
        let request = TerminalLaunchRequest(
            directory: ValidatedDirectory(path: "/tmp/demo", name: "demo")
        )

        _ = try launcher.launch(request)

        XCTAssertEqual(executor.scripts.count, 1)
        XCTAssertTrue(executor.scripts[0].contains("tell application \"iTerm\""))
    }

    func testLaunchMapsPermissionDeniedAndFallsBackToOpen() throws {
        let executor = StubAppleScriptExecutor(
            result: AppleScriptExecutionResult(exitCode: 1, stdout: "", stderr: "Not authorized to send Apple events to iTerm. (-1743)")
        )
        let opener = StubDirectoryOpener(
            result: AppleScriptExecutionResult(exitCode: 0, stdout: "", stderr: "")
        )
        let launcher = TerminalLauncher(
            executor: executor,
            directoryOpener: opener,
            detector: FixedTerminalAppDetector(.iterm2)
        )
        let request = TerminalLaunchRequest(
            directory: ValidatedDirectory(path: "/tmp/demo", name: "demo")
        )

        _ = try launcher.launch(request)

        XCTAssertEqual(opener.calls.count, 1)
        XCTAssertEqual(opener.calls[0].path, "/tmp/demo")
        XCTAssertEqual(opener.calls[0].arguments, ["-a", "iTerm2", "/tmp/demo"])
    }

    func testLaunchUsesOpenDirectlyForNonAppleScriptTerminals() throws {
        let opener = StubDirectoryOpener(
            result: AppleScriptExecutionResult(exitCode: 0, stdout: "", stderr: "")
        )
        let launcher = TerminalLauncher(
            executor: StubAppleScriptExecutor(
                result: AppleScriptExecutionResult(exitCode: 0, stdout: "", stderr: "")
            ),
            directoryOpener: opener,
            detector: FixedTerminalAppDetector(.warp)
        )
        let request = TerminalLaunchRequest(
            directory: ValidatedDirectory(path: "/tmp/demo", name: "demo")
        )

        _ = try launcher.launch(request)

        XCTAssertEqual(opener.calls.count, 1)
        XCTAssertEqual(opener.calls[0].arguments, ["-a", "Warp", "/tmp/demo"])
    }

    func testLaunchMapsGeneralFailures() throws {
        let executor = StubAppleScriptExecutor(
            result: AppleScriptExecutionResult(exitCode: 1, stdout: "", stderr: "execution error: bad script")
        )
        let launcher = TerminalLauncher(
            executor: executor,
            directoryOpener: nil,
            detector: FixedTerminalAppDetector(.iterm2)
        )
        let request = TerminalLaunchRequest(
            directory: ValidatedDirectory(path: "/tmp/demo", name: "demo")
        )

        XCTAssertThrowsError(try launcher.launch(request)) { error in
            XCTAssertEqual(error as? TerminalLaunchError, .launchFailed(reason: "execution error: bad script"))
        }
    }

    func testLaunchMapsPermissionDeniedWhenFallbackIsUnavailable() throws {
        let executor = StubAppleScriptExecutor(
            result: AppleScriptExecutionResult(exitCode: 1, stdout: "", stderr: "Not authorized to send Apple events to iTerm. (-1743)")
        )
        let launcher = TerminalLauncher(
            executor: executor,
            directoryOpener: nil,
            detector: FixedTerminalAppDetector(.iterm2)
        )
        let request = TerminalLaunchRequest(
            directory: ValidatedDirectory(path: "/tmp/demo", name: "demo")
        )

        XCTAssertThrowsError(try launcher.launch(request)) { error in
            XCTAssertEqual(error as? TerminalLaunchError, .permissionDenied)
        }
    }

    func testNonAppleScriptTerminalFailsWhenNoDirectoryOpener() {
        let launcher = TerminalLauncher(
            executor: StubAppleScriptExecutor(
                result: AppleScriptExecutionResult(exitCode: 0, stdout: "", stderr: "")
            ),
            directoryOpener: nil,
            detector: FixedTerminalAppDetector(.ghostty)
        )
        let request = TerminalLaunchRequest(
            directory: ValidatedDirectory(path: "/tmp/demo", name: "demo")
        )

        XCTAssertThrowsError(try launcher.launch(request)) { error in
            XCTAssertEqual(error as? TerminalLaunchError, .terminalUnavailable)
        }
    }
}

private final class StubAppleScriptExecutor: AppleScriptExecuting {
    private let result: AppleScriptExecutionResult
    private(set) var scripts: [String] = []

    init(result: AppleScriptExecutionResult) {
        self.result = result
    }

    func execute(script: String) throws -> AppleScriptExecutionResult {
        scripts.append(script)
        return result
    }
}

private final class StubDirectoryOpener: DirectoryOpening {
    struct Call: Equatable {
        let path: String
        let arguments: [String]
    }

    private let result: AppleScriptExecutionResult
    private(set) var calls: [Call] = []

    init(result: AppleScriptExecutionResult) {
        self.result = result
    }

    func open(directoryPath: String, arguments: [String]) throws -> AppleScriptExecutionResult {
        calls.append(Call(path: directoryPath, arguments: arguments))
        return result
    }
}
