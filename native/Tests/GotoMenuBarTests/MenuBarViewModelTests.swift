import Foundation
import XCTest

import GotoNativeCore
@testable import GotoMenuBar

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    func testReloadShowsFirstRunMessageWhenRegistryIsEmpty() {
        let viewModel = MenuBarViewModel(
            store: StubProjectStore(projects: []),
            launcher: StubTerminalLauncher()
        )

        viewModel.reload()

        XCTAssertEqual(viewModel.projects, [])
        XCTAssertEqual(viewModel.statusMessage, "Save a project with goto -a first.")
    }

    func testReloadShowsMissingProjectCount() {
        let projects = [
            ProjectEntry(name: "alpha", path: "/tmp/alpha", exists: true),
            ProjectEntry(name: "beta", path: "/tmp/beta", exists: false),
            ProjectEntry(name: "gamma", path: "/tmp/gamma", exists: false),
        ]

        let viewModel = MenuBarViewModel(
            store: StubProjectStore(projects: projects),
            launcher: StubTerminalLauncher()
        )

        viewModel.reload()

        XCTAssertEqual(viewModel.projects, projects)
        XCTAssertEqual(
            viewModel.statusMessage,
            "2 saved projects are missing. Remove them or refresh the registry."
        )
    }

    func testOpenMissingProjectDoesNotLaunch() {
        let launcher = StubTerminalLauncher()
        let viewModel = MenuBarViewModel(
            store: StubProjectStore(projects: []),
            launcher: launcher
        )

        viewModel.open(ProjectEntry(name: "missing", path: "/tmp/missing", exists: false))

        XCTAssertEqual(launcher.requests.count, 0)
        XCTAssertEqual(viewModel.statusMessage, "This project path no longer exists.")
    }

    func testOpenExistingProjectLaunchesTerminal() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let launcher = StubTerminalLauncher()
        let viewModel = MenuBarViewModel(
            store: StubProjectStore(projects: []),
            launcher: launcher
        )

        viewModel.open(ProjectEntry(name: "demo", path: directory.path, exists: true))

        XCTAssertEqual(
            launcher.requests,
            [
                TerminalLaunchRequest(
                    directory: ValidatedDirectory(path: directory.path, name: "demo"),
                    surface: .menuBar
                )
            ]
        )
        XCTAssertNil(viewModel.statusMessage)
    }

    func testOpenProjectRevalidatesDirectoryBeforeLaunch() throws {
        let launcher = StubTerminalLauncher()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.removeItem(at: directory)

        let viewModel = MenuBarViewModel(
            store: StubProjectStore(projects: []),
            launcher: launcher
        )

        viewModel.open(ProjectEntry(name: "demo", path: directory.path, exists: true))

        XCTAssertEqual(launcher.requests.count, 0)
        XCTAssertEqual(viewModel.statusMessage, "This project path no longer exists.")
    }

    func testOpenMapsPermissionFailureIntoUserMessage() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let launcher = StubTerminalLauncher(error: .permissionDenied)
        let viewModel = MenuBarViewModel(
            store: StubProjectStore(projects: []),
            launcher: launcher
        )

        viewModel.open(ProjectEntry(name: "demo", path: directory.path, exists: true))

        XCTAssertEqual(
            viewModel.statusMessage,
            "Allow goto to control Terminal in System Settings, then try again."
        )
    }
}

private struct StubProjectStore: ProjectListing {
    let projects: [ProjectEntry]

    func loadProjects() throws -> [ProjectEntry] {
        projects
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
