import Foundation

public struct LaunchDebouncer: Sendable {
    private var lastLaunch: (path: String, instant: Date)?
    private let minimumInterval: TimeInterval

    public init(minimumInterval: TimeInterval = 1.0) {
        self.minimumInterval = minimumInterval
    }

    public mutating func shouldLaunch(path: String, at instant: Date = Date()) -> Bool {
        if let lastLaunch,
           lastLaunch.path == path,
           instant.timeIntervalSince(lastLaunch.instant) < minimumInterval {
            return false
        }

        lastLaunch = (path, instant)
        return true
    }
}
