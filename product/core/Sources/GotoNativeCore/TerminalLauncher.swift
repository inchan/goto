import Foundation

public struct AppleScriptExecutionResult: Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol TerminalLaunching {
    @discardableResult
    func launch(_ request: TerminalLaunchRequest) throws -> AppleScriptExecutionResult
}

public protocol AppleScriptExecuting {
    func execute(script: String) throws -> AppleScriptExecutionResult
}

public protocol DirectoryOpening {
    func open(directoryPath: String, arguments: [String]) throws -> AppleScriptExecutionResult
}

public final class ProcessAppleScriptExecutor: AppleScriptExecuting {
    public init() {}

    public func execute(script: String) throws -> AppleScriptExecutionResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return AppleScriptExecutionResult(
            exitCode: process.terminationStatus,
            stdout: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

public final class OpenCommandDirectoryOpener: DirectoryOpening {
    public init() {}

    public func open(directoryPath: String, arguments: [String]) throws -> AppleScriptExecutionResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return AppleScriptExecutionResult(
            exitCode: process.terminationStatus,
            stdout: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

public struct TerminalLauncher {
    private let executor: AppleScriptExecuting
    private let directoryOpener: (any DirectoryOpening)?
    private let detector: any TerminalAppDetecting

    public init(
        executor: AppleScriptExecuting = ProcessAppleScriptExecutor(),
        directoryOpener: (any DirectoryOpening)? = OpenCommandDirectoryOpener(),
        detector: (any TerminalAppDetecting)? = nil,
        preferenceDefaults: UserDefaults = .standard,
        detectorFactory: (TerminalPreference) -> any TerminalAppDetecting = { preference in
            TerminalAppDetector(preference: preference)
        }
    ) {
        self.executor = executor
        self.directoryOpener = directoryOpener
        self.detector = detector ?? detectorFactory(
            TerminalPreference.load(from: preferenceDefaults)
        )
    }

    @discardableResult
    public func launch(_ request: TerminalLaunchRequest) throws -> AppleScriptExecutionResult {
        let terminalApp = detector.detect()
        let builder = TerminalScriptBuilder(terminalApp: terminalApp)
        Self.debug("launch start terminal=\(terminalApp.rawValue) supportsAppleScript=\(terminalApp.supportsAppleScript) path=\(request.directoryPath)")

        if terminalApp.supportsAppleScript {
            return try launchViaAppleScript(request: request, builder: builder, terminalApp: terminalApp)
        } else {
            return try launchViaOpen(request: request, builder: builder)
        }
    }

    private func launchViaAppleScript(
        request: TerminalLaunchRequest,
        builder: TerminalScriptBuilder,
        terminalApp: TerminalApp
    ) throws -> AppleScriptExecutionResult {
        Self.debug("launch via applescript terminal=\(terminalApp.rawValue) path=\(request.directoryPath)")
        let result = try executor.execute(script: builder.appleScript(forDirectory: request.directoryPath))
        Self.debug("applescript result terminal=\(terminalApp.rawValue) exit=\(result.exitCode) stdout=\(result.stdout) stderr=\(result.stderr)")

        guard result.exitCode == 0 else {
            let error = mapLaunchFailure(result)

            if error == .permissionDenied, let directoryOpener {
                Self.debug("applescript permission denied; falling back to open terminal=\(terminalApp.rawValue)")
                return try openDirectory(
                    request: request,
                    builder: builder,
                    directoryOpener: directoryOpener
                )
            }

            throw error
        }

        return result
    }

    private func launchViaOpen(
        request: TerminalLaunchRequest,
        builder: TerminalScriptBuilder
    ) throws -> AppleScriptExecutionResult {
        guard let directoryOpener else {
            throw TerminalLaunchError.terminalUnavailable
        }

        Self.debug("launch via open terminal=\(builder.terminalApp.rawValue) path=\(request.directoryPath)")
        return try openDirectory(
            request: request,
            builder: builder,
            directoryOpener: directoryOpener
        )
    }

    private func mapLaunchFailure(_ result: AppleScriptExecutionResult) -> TerminalLaunchError {
        let combined = [result.stdout, result.stderr]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        let lowered = combined.lowercased()
        if lowered.contains("not authorized") || combined.contains("-1743") {
            return .permissionDenied
        }

        if combined.isEmpty {
            return .launchFailed(reason: "osascript exited with code \(result.exitCode)")
        }

        return .launchFailed(reason: combined)
    }

    private func openDirectory(
        request: TerminalLaunchRequest,
        builder: TerminalScriptBuilder,
        directoryOpener: any DirectoryOpening
    ) throws -> AppleScriptExecutionResult {
        let args = builder.openCommand(forDirectory: request.directoryPath)
        Self.debug("open command terminal=\(builder.terminalApp.rawValue) args=\(args)")
        let result = try directoryOpener.open(directoryPath: request.directoryPath, arguments: args)
        Self.debug("open result terminal=\(builder.terminalApp.rawValue) exit=\(result.exitCode) stdout=\(result.stdout) stderr=\(result.stderr)")

        guard result.exitCode == 0 else {
            let combined = [result.stdout, result.stderr]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")

            if combined.isEmpty {
                throw TerminalLaunchError.launchFailed(
                    reason: "open exited with code \(result.exitCode)"
                )
            }

            throw TerminalLaunchError.launchFailed(reason: combined)
        }

        return result
    }
}

extension TerminalLauncher: TerminalLaunching {}

private extension TerminalLauncher {
    static let logURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("goto-launcher.log")
    static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    static func debug(_ message: String) {
        let line = "[\(dateFormatter.string(from: Date()))] \(message)\n"
        let data = Data(line.utf8)

        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: logURL)
        }
    }
}
