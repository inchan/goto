import Foundation

public struct TerminalLaunchCommandResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String = "", stderr: String = "") {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public struct TerminalLaunchCommand {
    private let selection: FinderSelection
    private let launcher: any TerminalLaunching
    private let presenter: FinderErrorPresenter

    public init(
        selection: FinderSelection = FinderSelection(),
        launcher: any TerminalLaunching = TerminalLauncher(),
        presenter: FinderErrorPresenter = FinderErrorPresenter()
    ) {
        self.selection = selection
        self.launcher = launcher
        self.presenter = presenter
    }

    public func run(arguments: [String]) -> TerminalLaunchCommandResult {
        let executableName = URL(fileURLWithPath: arguments.first ?? "GotoNativeLaunch").lastPathComponent

        do {
            let options = try parse(arguments: Array(arguments.dropFirst()))
            let directory = try selection.resolveSelectedDirectory(
                from: [URL(fileURLWithPath: options.path, isDirectory: true)]
            )

            if options.dryRun {
                return TerminalLaunchCommandResult(exitCode: 0, stdout: directory.path)
            }

            let request = TerminalLaunchRequest(directory: directory, surface: .finder)
            try launcher.launch(request)
            return TerminalLaunchCommandResult(exitCode: 0)
        } catch let error as TerminalLaunchCommandUsageError {
            return TerminalLaunchCommandResult(
                exitCode: 64,
                stderr: error.message(for: executableName)
            )
        } catch let error as FinderSelectionError {
            let userFacing = presenter.present(selectionError: error)
            return TerminalLaunchCommandResult(
                exitCode: 1,
                stderr: "\(userFacing.title): \(userFacing.message)"
            )
        } catch let error as TerminalLaunchError {
            let userFacing = presenter.present(launchError: error)
            return TerminalLaunchCommandResult(
                exitCode: 1,
                stderr: "\(userFacing.title): \(userFacing.message)"
            )
        } catch {
            return TerminalLaunchCommandResult(exitCode: 1, stderr: error.localizedDescription)
        }
    }

    private func parse(arguments: [String]) throws -> ParsedOptions {
        var dryRun = false
        var path: String?

        for argument in arguments {
            switch argument {
            case "--dry-run":
                dryRun = true
            case _ where argument.hasPrefix("-"):
                throw TerminalLaunchCommandUsageError.invalidOption(argument)
            default:
                guard path == nil else {
                    throw TerminalLaunchCommandUsageError.expectsSinglePath
                }

                path = argument
            }
        }

        guard let path else {
            throw TerminalLaunchCommandUsageError.missingPath
        }

        return ParsedOptions(dryRun: dryRun, path: path)
    }
}

private struct ParsedOptions {
    let dryRun: Bool
    let path: String
}

private enum TerminalLaunchCommandUsageError: Error {
    case invalidOption(String)
    case missingPath
    case expectsSinglePath

    func message(for executableName: String) -> String {
        switch self {
        case let .invalidOption(option):
            return "Unsupported option: \(option)\nUsage: \(executableName) [--dry-run] <folder-path>"
        case .missingPath, .expectsSinglePath:
            return "Usage: \(executableName) [--dry-run] <folder-path>"
        }
    }
}
