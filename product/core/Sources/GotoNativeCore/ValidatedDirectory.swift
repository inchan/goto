import Foundation

public struct ValidatedDirectory: Equatable, Sendable {
    public let path: String
    public let name: String

    public init(path: String, name: String? = nil) {
        self.path = path

        if let name, !name.isEmpty {
            self.name = name
        } else {
            let derivedName = URL(fileURLWithPath: path).lastPathComponent
            self.name = derivedName.isEmpty ? path : derivedName
        }
    }

    public var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }
}
