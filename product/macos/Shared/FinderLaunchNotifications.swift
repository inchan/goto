import Foundation

enum FinderLaunchNotification {
    static let pathKey = "path"
    static let modeKey = "mode"
    static let currentFinderFolderMode = "currentFinderFolder"
}

enum FinderLaunchRequest: Equatable {
    case path(String)
    case currentFinderFolder
}

enum FinderLaunchURL {
    static let scheme = "goto-finder"

    static func makePathURL(path: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "open"
        components.queryItems = [URLQueryItem(name: FinderLaunchNotification.pathKey, value: path)]
        return components.url
    }

    static func makeCurrentFinderFolderURL() -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "current-finder-folder"
        return components.url
    }

    static func parse(_ url: URL) -> FinderLaunchRequest? {
        guard url.scheme == scheme else {
            return nil
        }

        switch url.host {
        case "open":
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let path = components.queryItems?.first(where: { $0.name == FinderLaunchNotification.pathKey })?.value,
                !path.isEmpty
            else {
                return nil
            }

            return .path(path)
        case "current-finder-folder":
            return .currentFinderFolder
        default:
            return nil
        }
    }
}

extension Notification.Name {
    static let gotoFinderLaunchRequested = Notification.Name("dev.goto.finder-sync.launch-requested")
    static let gotoFinderObservedDirectoryBegan = Notification.Name("dev.goto.finder-sync.observed-directory-began")
    static let gotoFinderObservedDirectoryEnded = Notification.Name("dev.goto.finder-sync.observed-directory-ended")
    static let gotoProjectListUpdated = Notification.Name("dev.goto.project-list-updated")
    static let gotoFinderPreferenceUpdated = Notification.Name("dev.goto.finder-preference-updated")
    static let gotoExtensionReady = Notification.Name("dev.goto.extension-ready")
}

enum FinderSyncBroadcast {
    static let projectsKey = "projects"  // JSON-encoded [[name, path]]
    static let clickModeKey = "clickMode"
    static let enabledKey = "enabled"

    static func encodeProjects(_ projects: [String]) -> String {
        // Simple: newline-separated paths
        projects.joined(separator: "\n")
    }

    static func decodeProjects(_ string: String) -> [String] {
        string.split(separator: "\n").map(String.init)
    }
}
