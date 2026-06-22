import XCTest

final class GotoWatchedSyncTests: XCTestCase {
    private var tempRoot: URL!
    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("GotoWatchedSyncTests-\(UUID().uuidString)", isDirectory: true)
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

    // 1. addSubdirs 호출 후 parent가 watched에 등록됨
    func testAddSubdirsRegistersParentAsWatched() throws {
        let parent = try makeDirectory("parent")
        let repo = try makeGitRepo(under: parent, name: "repo")

        XCTAssertEqual(try GotoProjectStore.addSubdirs(parent.path), 1)
        XCTAssertTrue(GotoProjectStore.load().contains(repo.path))

        let watched = GotoProjectStore.loadWatched()
        XCTAssertTrue(watched.contains(GotoProjectStore.normalize(parent.path)))
    }

    // 2. watched parent 하위에 새 git 루트 생성 후 syncWatched → added>=1, load()에 포함
    func testSyncAddsNewGitRootUnderWatchedParent() throws {
        let parent = try makeDirectory("parent")
        _ = try makeGitRepo(under: parent, name: "first")
        XCTAssertEqual(try GotoProjectStore.addSubdirs(parent.path), 1)

        let second = try makeGitRepo(under: parent, name: "second")

        let result = GotoProjectStore.syncWatched()
        XCTAssertGreaterThanOrEqual(result.added, 1)
        XCTAssertTrue(GotoProjectStore.load().contains(second.path))
    }

    // 3. 등록된 직속 폴더를 삭제 후 syncWatched → removed>=1, load()에서 빠짐
    func testSyncRemovesDeletedChildDirectory() throws {
        let parent = try makeDirectory("parent")
        let repo = try makeGitRepo(under: parent, name: "repo")
        XCTAssertEqual(try GotoProjectStore.addSubdirs(parent.path), 1)
        XCTAssertTrue(GotoProjectStore.load().contains(repo.path))

        try FileManager.default.removeItem(at: repo)

        let result = GotoProjectStore.syncWatched()
        XCTAssertGreaterThanOrEqual(result.removed, 1)
        XCTAssertFalse(GotoProjectStore.load().contains(repo.path))
    }

    // 4. .git만 제거(폴더는 존재)하고 syncWatched → 제거되지 않음
    func testSyncKeepsDirectoryWhenOnlyGitRemoved() throws {
        let parent = try makeDirectory("parent")
        let repo = try makeGitRepo(under: parent, name: "repo")
        XCTAssertEqual(try GotoProjectStore.addSubdirs(parent.path), 1)
        XCTAssertTrue(GotoProjectStore.load().contains(repo.path))

        // 폴더는 그대로 두고 .git만 제거
        try FileManager.default.removeItem(at: repo.appendingPathComponent(".git", isDirectory: true))

        let result = GotoProjectStore.syncWatched()
        XCTAssertEqual(result.removed, 0)
        XCTAssertTrue(GotoProjectStore.load().contains(repo.path))
    }

    // 5. watched parent 자체 삭제 후 syncWatched → 하위 등록 정리 + loadWatched()에서 parent 제거
    func testSyncCleansUpWhenWatchedParentDeleted() throws {
        let parent = try makeDirectory("parent")
        let repo = try makeGitRepo(under: parent, name: "repo")
        XCTAssertEqual(try GotoProjectStore.addSubdirs(parent.path), 1)
        XCTAssertTrue(GotoProjectStore.load().contains(repo.path))
        XCTAssertTrue(GotoProjectStore.loadWatched().contains(GotoProjectStore.normalize(parent.path)))

        try FileManager.default.removeItem(at: parent)

        let result = GotoProjectStore.syncWatched()
        XCTAssertGreaterThanOrEqual(result.removed, 1)
        XCTAssertFalse(GotoProjectStore.load().contains(repo.path))
        XCTAssertFalse(GotoProjectStore.loadWatched().contains(GotoProjectStore.normalize(parent.path)))
    }

    // 6. removeWatched 후 syncWatched가 그 parent를 동기화하지 않음
    func testSyncIgnoresParentAfterRemoveWatched() throws {
        let parent = try makeDirectory("parent")
        _ = try makeGitRepo(under: parent, name: "first")
        XCTAssertEqual(try GotoProjectStore.addSubdirs(parent.path), 1)

        let normalizedParent = GotoProjectStore.normalize(parent.path)
        XCTAssertTrue(GotoProjectStore.removeWatched(parent.path))
        XCTAssertFalse(GotoProjectStore.loadWatched().contains(normalizedParent))

        // 감시 해제 후 새 git 루트를 추가해도 sync가 잡지 않아야 함
        let second = try makeGitRepo(under: parent, name: "second")

        let result = GotoProjectStore.syncWatched()
        XCTAssertEqual(result.added, 0)
        XCTAssertFalse(GotoProjectStore.load().contains(second.path))
    }

    // MARK: - Helpers

    private func makeDirectory(_ name: String) throws -> URL {
        let url = tempRoot.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeGitRepo(under parent: URL, name: String) throws -> URL {
        let url = parent.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try runGit(["init"], in: url)
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
