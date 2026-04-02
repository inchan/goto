import Foundation

public struct TerminalLaunchRequest: Equatable, Sendable {
    public let directory: ValidatedDirectory

    public init(directory: ValidatedDirectory) {
        self.directory = directory
    }

    public var directoryPath: String {
        directory.path
    }

    public var displayName: String {
        directory.name
    }
}
