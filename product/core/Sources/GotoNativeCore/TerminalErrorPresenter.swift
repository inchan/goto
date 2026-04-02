import Foundation

public struct UserFacingError: Equatable, Sendable {
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

public struct TerminalErrorPresenter: Sendable {
    public init() {}

    public func present(launchError: TerminalLaunchError) -> UserFacingError {
        switch launchError {
        case .permissionDenied:
            return UserFacingError(
                title: "Terminal Permission Required",
                message: "Allow goto to control Terminal in System Settings, then try again."
            )
        case .terminalUnavailable:
            return UserFacingError(
                title: "Terminal Unavailable",
                message: "Terminal.app could not be found on this Mac."
            )
        case let .launchFailed(reason):
            return UserFacingError(
                title: "Could Not Open Terminal",
                message: reason
            )
        }
    }
}
