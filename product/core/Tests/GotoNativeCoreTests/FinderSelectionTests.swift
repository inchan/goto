import Foundation
import XCTest

@testable import GotoNativeCore

final class FinderSelectionTests: XCTestCase {
    func testResolveSelectedDirectoryAcceptsExistingFolder() throws {
        let workspace = try temporaryDirectory()
        let folder = workspace.appendingPathComponent("demo", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let selection = FinderSelection()
        let result = try selection.resolveSelectedDirectory(from: [folder])

        XCTAssertEqual(result, ValidatedDirectory(path: folder.path, name: "demo"))
    }

    func testResolveSelectedDirectoryRejectsMissingPath() throws {
        let workspace = try temporaryDirectory()
        let missing = workspace.appendingPathComponent("missing", isDirectory: true)

        let selection = FinderSelection()

        XCTAssertThrowsError(try selection.resolveSelectedDirectory(from: [missing])) { error in
            XCTAssertEqual(error as? FinderSelectionError, .missingPath(missing.path))
        }
    }

    func testResolveSelectedDirectoryRejectsFileSelection() throws {
        let workspace = try temporaryDirectory()
        let file = workspace.appendingPathComponent("notes.txt", isDirectory: false)
        try Data("hello".utf8).write(to: file)

        let selection = FinderSelection()

        XCTAssertThrowsError(try selection.resolveSelectedDirectory(from: [file])) { error in
            XCTAssertEqual(error as? FinderSelectionError, .notDirectory(file.path))
        }
    }

    func testResolveSelectedDirectoryRejectsMultipleSelections() {
        let selection = FinderSelection()
        let alpha = URL(fileURLWithPath: "/tmp/alpha", isDirectory: true)
        let beta = URL(fileURLWithPath: "/tmp/beta", isDirectory: true)

        XCTAssertThrowsError(try selection.resolveSelectedDirectory(from: [alpha, beta])) { error in
            XCTAssertEqual(error as? FinderSelectionError, .multipleSelections(count: 2))
        }
    }

    func testResolveSelectedDirectoryPreservesNonAsciiPaths() throws {
        let workspace = try temporaryDirectory()
        let folder = workspace.appendingPathComponent("프로젝트", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let selection = FinderSelection()
        let result = try selection.resolveSelectedDirectory(from: [folder])

        XCTAssertEqual(result.path, folder.path)
        XCTAssertEqual(result.name, "프로젝트")
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
