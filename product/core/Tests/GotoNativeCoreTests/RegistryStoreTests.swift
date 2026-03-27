import Foundation
import XCTest

@testable import GotoNativeCore

final class RegistryStoreTests: XCTestCase {
    func testParseEntriesTrimsBlankLinesAndDeduplicatesInOrder() {
        let contents = """

        /tmp/alpha
        /tmp/beta
        /tmp/alpha

        /tmp/gamma
        """

        XCTAssertEqual(
            RegistryStore.parseEntries(contents),
            ["/tmp/alpha", "/tmp/beta", "/tmp/gamma"]
        )
    }

    func testLoadProjectsPreservesOrderAndMarksMissingEntries() throws {
        let workspace = try temporaryDirectory()
        let alpha = workspace.appendingPathComponent("alpha", isDirectory: true)
        let beta = workspace.appendingPathComponent("beta", isDirectory: true)
        let missing = workspace.appendingPathComponent("missing", isDirectory: true)
        let registryURL = workspace.appendingPathComponent(".goto", isDirectory: false)

        try FileManager.default.createDirectory(at: alpha, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: beta, withIntermediateDirectories: true)
        try """
        \(alpha.path)
        \(missing.path)
        \(beta.path)
        """.write(to: registryURL, atomically: true, encoding: .utf8)

        let store = RegistryStore(registryURL: registryURL)
        let projects = try store.loadProjects()

        XCTAssertEqual(
            projects,
            [
                ProjectEntry(name: "alpha", path: alpha.path, exists: true),
                ProjectEntry(name: "missing", path: missing.path, exists: false),
                ProjectEntry(name: "beta", path: beta.path, exists: true),
            ]
        )
    }

    func testReadEntriesReturnsEmptyWhenRegistryIsMissing() throws {
        let workspace = try temporaryDirectory()
        let registryURL = workspace.appendingPathComponent(".goto", isDirectory: false)

        let store = RegistryStore(registryURL: registryURL)
        XCTAssertEqual(try store.readEntries(), [])
    }

    func testEnvironmentInitializerUsesHomeDirectory() throws {
        let workspace = try temporaryDirectory()
        let homeDirectory = workspace.appendingPathComponent("home", isDirectory: true)
        let project = homeDirectory.appendingPathComponent("workspace/demo", isDirectory: true)
        let registryURL = homeDirectory.appendingPathComponent(".goto", isDirectory: false)

        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try "\(project.path)\n".write(to: registryURL, atomically: true, encoding: .utf8)

        let store = RegistryStore(environment: ["HOME": homeDirectory.path])
        let projects = try store.loadProjects()

        XCTAssertEqual(projects, [ProjectEntry(name: "demo", path: project.path, exists: true)])
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
