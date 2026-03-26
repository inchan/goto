import Foundation

public enum LaunchSurface: String, Equatable, Sendable {
    case menuBar
    case finder
}

public struct TerminalLaunchRequest: Equatable, Sendable {
    public let directory: ValidatedDirectory
    public let surface: LaunchSurface

    public init(directory: ValidatedDirectory, surface: LaunchSurface) {
        self.directory = directory
        self.surface = surface
    }

    public var directoryPath: String {
        directory.path
    }

    public var displayName: String {
        directory.name
    }
}
