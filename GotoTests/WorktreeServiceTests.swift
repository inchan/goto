import XCTest

final class WorktreeServiceTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorktreeServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        try super.tearDownWithError()
    }

    func testWorktreesInvokesRealGitRepository() throws {
        let repo = tempRoot.appendingPathComponent("repo", isDirectory: true)
        let linked = tempRoot.appendingPathComponent("repo-feature", isDirectory: true)
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)

        try runGit(["init"], in: repo)
        try runGit(["config", "user.email", "goto-tests@example.com"], in: repo)
        try runGit(["config", "user.name", "Goto Tests"], in: repo)
        try "initial\n".write(to: repo.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try runGit(["add", "README.md"], in: repo)
        try runGit(["commit", "-m", "Initial commit"], in: repo)
        try runGit(["worktree", "add", "-b", "feature/test", linked.path], in: repo)

        let result = WorktreeService.worktrees(
            at: repo.path,
            gitExecutable: WorktreeService.defaultGitExecutableURL
        )

        guard case .success(let entries) = result else {
            return XCTFail("expected worktree success, got \(result)")
        }

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(
            entries.first.map { URL(fileURLWithPath: $0.path).resolvingSymlinksInPath().path },
            linked.resolvingSymlinksInPath().path
        )
        XCTAssertEqual(entries.first?.branch, "feature/test")
        XCTAssertEqual(entries.first?.isCurrent, false)
    }

    func testParsePorcelainFiltersBarePrunableAndCurrentEntries() {
        let output = """
        worktree /private/tmp
        HEAD 1111111111111111111111111111111111111111
        branch refs/heads/main

        worktree /tmp/repo-feature
        HEAD 2222222222222222222222222222222222222222
        branch refs/heads/feature/test

        worktree /tmp/repo-detached
        HEAD 3333333333333333333333333333333333333333
        detached

        worktree /tmp/repo-bare
        bare

        worktree /tmp/repo-prunable
        HEAD 4444444444444444444444444444444444444444
        branch refs/heads/old
        prunable gitdir file points to non-existent location
        """

        let result = WorktreeService.parsePorcelain(output, repoRoot: "/tmp")

        guard case .success(let entries) = result else {
            return XCTFail("expected parse success, got \(result)")
        }

        XCTAssertEqual(entries, [
            GotoWorktreeEntry(
                path: "/tmp/repo-feature",
                branch: "feature/test",
                isCurrent: false,
                isBare: false,
                isPrunable: false
            ),
            GotoWorktreeEntry(
                path: "/tmp/repo-detached",
                branch: nil,
                isCurrent: false,
                isBare: false,
                isPrunable: false
            ),
        ])
    }

    func testParsePorcelainFailsWhenWorktreePathIsMissing() {
        let result = WorktreeService.parsePorcelain("HEAD abc\nbranch refs/heads/main", repoRoot: "/tmp/repo")

        guard case .failure(.parseFailed(let message)) = result else {
            return XCTFail("expected parseFailed, got \(result)")
        }

        XCTAssertFalse(message.isEmpty)
    }

    private func runGit(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = WorktreeService.defaultGitExecutableURL
        process.arguments = arguments
        process.currentDirectoryURL = directory

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("git \(arguments.joined(separator: " ")) failed: \(stderrText)")
        }
    }
}
