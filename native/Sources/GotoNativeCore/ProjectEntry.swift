import Foundation

public struct ProjectEntry: Equatable, Sendable {
    public let name: String
    public let path: String
    public let exists: Bool

    public init(name: String, path: String, exists: Bool) {
        self.name = name
        self.path = path
        self.exists = exists
    }
}
