import XCTest

final class GotoProjectStoreTests: XCTestCase {
    private var tempRoot: URL!
    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("GotoProjectStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        storeURL = tempRoot.appendingPathComponent(".goto")
        GotoProjectStore.storeURLOverride = storeURL
    }

    override func tearDownWithError() throws {
        GotoProjectStore.storeURLOverride = nil
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        try super.tearDownWithError()
    }

    func testNormalizeExpandsTildeAbsoluteSymlinkAndTrailingSlash() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        XCTAssertEqual(GotoProjectStore.normalize("~/"), home)

        let target = tempRoot.appendingPathComponent("target", isDirectory: true)
        let link = tempRoot.appendingPathComponent("link", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let normalized = GotoProjectStore.normalize(link.path + "/")
        XCTAssertEqual(normalized, target.resolvingSymlinksInPath().path)
        XCTAssertFalse(normalized.hasSuffix("/"))
    }

    func testAddRemoveRoundTripDeduplicatesAndSorts() throws {
        let beta = try makeDirectory("beta")
        let alpha = try makeDirectory("alpha")

        XCTAssertTrue(try GotoProjectStore.add(beta.path))
        XCTAssertTrue(try GotoProjectStore.add(alpha.path))
        XCTAssertFalse(try GotoProjectStore.add(alpha.path))
        XCTAssertEqual(GotoProjectStore.load(), [alpha.path, beta.path].sorted())

        XCTAssertTrue(try GotoProjectStore.remove(beta.path))
        XCTAssertFalse(try GotoProjectStore.remove(beta.path))
        XCTAssertEqual(GotoProjectStore.load(), [alpha.path])
    }

    func testAddRejectsNonDirectory() throws {
        let file = tempRoot.appendingPathComponent("file.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try GotoProjectStore.add(file.path)) { error in
            guard case GotoProjectStoreError.pathNotDirectory(let path) = error else {
                return XCTFail("expected pathNotDirectory, got \(error)")
            }
            XCTAssertEqual(path, file.path)
        }
    }

    func testAddSubdirsAddsOnlyGitManagedDirectories() throws {
        let parent = try makeDirectory("parent")
        let gitRepo = parent.appendingPathComponent("git-repo", isDirectory: true)
        let worktreeStyleRepo = parent.appendingPathComponent("worktree-style-repo", isDirectory: true)
        let nestedRepoChild = gitRepo.appendingPathComponent("nested-child", isDirectory: true)
        let plain = parent.appendingPathComponent("plain", isDirectory: true)
        let fakeGit = parent.appendingPathComponent("fake-git", isDirectory: true)
        let dot = parent.appendingPathComponent(".hidden", isDirectory: true)
        let file = parent.appendingPathComponent("file.txt")
        try FileManager.default.createDirectory(at: gitRepo, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: worktreeStyleRepo, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nestedRepoChild, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: fakeGit, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dot, withIntermediateDirectories: true)
        try runGit(["init"], in: gitRepo)
        try runGit(["init"], in: worktreeStyleRepo)
        try FileManager.default.createDirectory(at: fakeGit.appendingPathComponent(".git", isDirectory: true), withIntermediateDirectories: true)
        try runGit(["init"], in: dot)
        try "x".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertEqual(try GotoProjectStore.addSubdirs(parent.path), 2)
        XCTAssertEqual(GotoProjectStore.load(), [gitRepo.path, worktreeStyleRepo.path].sorted())
    }

    func testAddSubdirsReportsUnreadableParent() throws {
        let file = tempRoot.appendingPathComponent("not-a-directory")
        try "x".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try GotoProjectStore.addSubdirs(file.path)) { error in
            guard case GotoProjectStoreError.pathNotDirectory(let path) = error else {
                return XCTFail("expected pathNotDirectory, got \(error)")
            }
            XCTAssertEqual(path, file.path)
        }
    }

    func testRemoveSubdirsOnlyRemovesImmediateChildrenWithExactPrefix() throws {
        let parent = tempRoot.appendingPathComponent("foo", isDirectory: true)
        let child = parent.appendingPathComponent("child", isDirectory: true)
        let nested = child.appendingPathComponent("nested", isDirectory: true)
        let siblingPrefix = tempRoot.appendingPathComponent("foobar", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: siblingPrefix, withIntermediateDirectories: true)

        let entries = [child.path, nested.path, siblingPrefix.path].joined(separator: "\n") + "\n"
        try entries.write(to: storeURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(try GotoProjectStore.removeSubdirs(parent.path), 1)
        XCTAssertEqual(GotoProjectStore.load(), [nested.path, siblingPrefix.path].sorted())
    }

    private func makeDirectory(_ name: String) throws -> URL {
        let url = tempRoot.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func runGit(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = directory
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }
}
