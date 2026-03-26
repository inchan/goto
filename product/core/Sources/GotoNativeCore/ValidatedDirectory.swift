import Foundation

public struct ValidatedDirectory: Equatable, Sendable {
    public let path: String
    public let name: String

    public init(path: String, name: String? = nil) {
        self.path = path
        self.name = name ?? RegistryStore.projectName(for: path)
    }

    public var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }
}
