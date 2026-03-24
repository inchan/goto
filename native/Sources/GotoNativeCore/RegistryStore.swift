import Foundation

public protocol ProjectListing {
    func loadProjects() throws -> [ProjectEntry]
}

public struct RegistryStore: Sendable {
    public let registryURL: URL

    public init(registryURL: URL) {
        self.registryURL = registryURL
    }

    public init(homeDirectoryURL: URL) {
        self.init(registryURL: Self.defaultRegistryURL(homeDirectoryURL: homeDirectoryURL))
    }

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.init(homeDirectoryURL: Self.resolveHomeDirectoryURL(environment: environment))
    }

    public static func resolveHomeDirectoryURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let home = environment["HOME"], !home.isEmpty {
            return URL(fileURLWithPath: home, isDirectory: true)
        }

        return FileManager.default.homeDirectoryForCurrentUser
    }

    public static func defaultRegistryURL(homeDirectoryURL: URL) -> URL {
        homeDirectoryURL.appendingPathComponent(".goto", isDirectory: false)
    }

    public func readEntries() throws -> [String] {
        guard FileManager.default.fileExists(atPath: registryURL.path) else {
            return []
        }

        let contents = try String(contentsOf: registryURL, encoding: .utf8)
        return Self.parseEntries(contents)
    }

    public func loadProjects() throws -> [ProjectEntry] {
        try readEntries().map { path in
            ProjectEntry(
                name: Self.projectName(for: path),
                path: path,
                exists: Self.directoryExists(at: path)
            )
        }
    }

    public static func parseEntries(_ contents: String) -> [String] {
        var seen = Set<String>()
        var entries: [String] = []

        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            let entry = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if entry.isEmpty {
                continue
            }

            if seen.insert(entry).inserted {
                entries.append(entry)
            }
        }

        return entries
    }

    public static func projectName(for path: String) -> String {
        let name = URL(fileURLWithPath: path).lastPathComponent
        return name.isEmpty ? path : name
    }

    public static func directoryExists(at path: String) -> Bool {
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}

extension RegistryStore: ProjectListing {}
