import Foundation

public enum TerminalPermissionState: String, Equatable, Sendable {
    case unknown
    case granted
    case denied
}

public enum TerminalLaunchError: Error, Equatable, Sendable {
    case permissionDenied
    case terminalUnavailable
    case launchFailed(reason: String)
}
