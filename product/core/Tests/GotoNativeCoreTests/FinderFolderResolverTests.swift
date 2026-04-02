import XCTest
@testable import GotoNativeCore

final class FinderFolderResolverTests: XCTestCase {
    func testResolvedFolderURLReturnsSelectedFolderAsIs() throws {
        let folderURL = try makeTemporaryDirectory(named: "demo")

        let resolved = FinderFolderResolver.resolvedFolderURL(
            selectedItemURLs: [folderURL],
            targetedURL: nil
        )

        XCTAssertEqual(resolved, folderURL)
    }

    func testResolvedFolderURLReturnsParentDirectoryForSelectedFile() throws {
        let folderURL = try makeTemporaryDirectory(named: "demo")
        let fileURL = folderURL.appendingPathComponent("readme.md")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("hello".utf8))

        let resolved = FinderFolderResolver.resolvedFolderURL(
            selectedItemURLs: [fileURL],
            targetedURL: nil
        )

        XCTAssertEqual(resolved, folderURL)
    }

    func testResolvedFolderURLFallsBackToTargetedURL() throws {
        let targetedURL = try makeTemporaryDirectory(named: "demo")

        let resolved = FinderFolderResolver.resolvedFolderURL(
            selectedItemURLs: nil,
            targetedURL: targetedURL
        )

        XCTAssertEqual(resolved, targetedURL)
    }

    func testResolvedFolderURLReturnsNilWhenNothingIsSelected() {
        let resolved = FinderFolderResolver.resolvedFolderURL(
            selectedItemURLs: nil,
            targetedURL: nil
        )

        XCTAssertNil(resolved)
    }

    private func makeTemporaryDirectory(named name: String) throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)

        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
}
