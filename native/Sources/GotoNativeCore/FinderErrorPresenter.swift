import Foundation

public struct UserFacingError: Equatable, Sendable {
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

public struct FinderErrorPresenter: Sendable {
    public init() {}

    public func present(selectionError: FinderSelectionError) -> UserFacingError {
        switch selectionError {
        case .emptySelection:
            return UserFacingError(
                title: "No Folder Selected",
                message: "Select one folder in Finder, then try goto again."
            )
        case let .multipleSelections(count):
            return UserFacingError(
                title: "Select One Folder",
                message: "goto can open one folder at a time. You selected \(count) items."
            )
        case let .unsupportedURL(value):
            return UserFacingError(
                title: "Unsupported Selection",
                message: "goto only supports local folders. The selected item was \(value)."
            )
        case let .missingPath(path):
            return UserFacingError(
                title: "Folder Not Found",
                message: "The selected folder no longer exists: \(path)"
            )
        case let .notDirectory(path):
            return UserFacingError(
                title: "Not a Folder",
                message: "goto can only open folders in Terminal. The selected item was \(path)."
            )
        }
    }

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
