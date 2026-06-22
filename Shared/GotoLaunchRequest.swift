import Foundation

enum GotoLaunchAction: Equatable {
    case openTerminal(path: String?)
}

enum GotoLaunchRequest {
    static let scheme = "gotolauncher"          // GotoLauncher.app — Open in Terminal

    static func url(path: String?) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "open"

        if let path, !path.isEmpty {
            components.queryItems = [URLQueryItem(name: "path", value: path)]
        }

        return components.url
    }

    static func parse(url: URL) -> GotoLaunchAction? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let pathValue = components?.queryItems?.first(where: { $0.name == "path" })?.value

        switch url.scheme {
        case scheme:
            if url.host == "open" {
                return .openTerminal(path: pathValue)
            }
        default:
            break
        }
        return nil
    }

    static func path(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == "open" else {
            return nil
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "path" })?.value
    }
}
