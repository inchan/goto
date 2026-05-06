import Foundation

struct GotoWorktreeEntry: Codable, Hashable {
    let path: String
    let branch: String?
    let isCurrent: Bool
    let isBare: Bool
    let isPrunable: Bool
}

enum WorktreeServiceError: Error {
    case notARepository
    case gitFailed(stderr: String, status: Int32)
    case parseFailed(String)
}

enum WorktreeService {

    static var defaultGitExecutableURL: URL {
        let candidates = [
            "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
            "/Library/Developer/CommandLineTools/usr/bin/git",
            "/usr/bin/git",
        ]
        let fm = FileManager.default
        for candidate in candidates where fm.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }
        return URL(fileURLWithPath: candidates.last!)
    }

    static func worktrees(
        at repoPath: String,
        gitExecutable: URL
    ) -> Result<[GotoWorktreeEntry], WorktreeServiceError> {

        let insideResult = runGit(
            executable: gitExecutable,
            arguments: ["-C", repoPath, "rev-parse", "--is-inside-work-tree"],
            workingDirectory: repoPath
        )
        switch insideResult {
        case .failure(let err):
            if case .gitFailed = err {
                return .failure(.notARepository)
            }
            return .failure(err)
        case .success(let output):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed == "true" else {
                return .failure(.notARepository)
            }
        }

        let rootResult = runGit(
            executable: gitExecutable,
            arguments: ["-C", repoPath, "rev-parse", "--show-toplevel"],
            workingDirectory: repoPath
        )
        let repoRoot: String
        switch rootResult {
        case .failure(let err):
            return .failure(err)
        case .success(let output):
            repoRoot = output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let listResult = runGit(
            executable: gitExecutable,
            arguments: ["-C", repoPath, "worktree", "list", "--porcelain"],
            workingDirectory: repoPath
        )
        let porcelain: String
        switch listResult {
        case .failure(let err):
            return .failure(err)
        case .success(let output):
            porcelain = output
        }

        return parsePorcelain(porcelain, repoRoot: repoRoot)
    }

    private static func runGit(
        executable: URL,
        arguments: [String],
        workingDirectory: String
    ) -> Result<String, WorktreeServiceError> {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return .failure(.gitFailed(stderr: error.localizedDescription, status: -1))
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        let status = process.terminationStatus

        if status != 0 {
            return .failure(.gitFailed(stderr: stderr, status: status))
        }

        return .success(stdout)
    }

    static func parsePorcelain(
        _ output: String,
        repoRoot: String
    ) -> Result<[GotoWorktreeEntry], WorktreeServiceError> {
        let canonicalRoot = URL(fileURLWithPath: repoRoot)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path

        let blocks = output.components(separatedBy: "\n\n")

        var entries: [GotoWorktreeEntry] = []

        for block in blocks {
            let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedBlock.isEmpty else { continue }

            let lines = trimmedBlock.components(separatedBy: "\n")

            var worktreePath: String?
            var branch: String?
            var isBare = false
            var isPrunable = false

            for line in lines {
                if line.hasPrefix("worktree ") {
                    worktreePath = String(line.dropFirst("worktree ".count))
                } else if line.hasPrefix("branch ") {
                    let ref = String(line.dropFirst("branch ".count))
                    if ref.hasPrefix("refs/heads/") {
                        branch = String(ref.dropFirst("refs/heads/".count))
                    } else {
                        branch = ref
                    }
                } else if line == "bare" {
                    isBare = true
                } else if line.hasPrefix("prunable") {
                    isPrunable = true
                }
            }

            guard let path = worktreePath else {
                return .failure(.parseFailed("worktree 블록에서 path를 찾을 수 없습니다"))
            }

            let canonicalPath = URL(fileURLWithPath: path)
                .standardizedFileURL
                .resolvingSymlinksInPath()
                .path

            let isCurrent = canonicalPath == canonicalRoot

            entries.append(GotoWorktreeEntry(
                path: path,
                branch: branch,
                isCurrent: isCurrent,
                isBare: isBare,
                isPrunable: isPrunable
            ))
        }

        let visibleEntries = entries.filter { !$0.isBare && !$0.isPrunable && !$0.isCurrent }
        return .success(visibleEntries)
    }
}
