import Foundation

public struct SharedSettings: Sendable {
    public let settingsURL: URL

    public init(settingsURL: URL) {
        self.settingsURL = settingsURL
    }

    public init(homeDirectoryURL: URL) {
        self.init(settingsURL: Self.defaultSettingsURL(homeDirectoryURL: homeDirectoryURL))
    }

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.init(homeDirectoryURL: RegistryStore.resolveHomeDirectoryURL(environment: environment))
    }

    public static func defaultSettingsURL(homeDirectoryURL: URL) -> URL {
        homeDirectoryURL.appendingPathComponent(".goto-settings", isDirectory: false)
    }

    public func loadFinderPreference() -> FinderPreference {
        do {
            let data = try Data(contentsOf: settingsURL)
            let wrapper = try JSONDecoder().decode(SettingsWrapper.self, from: data)
            return wrapper.finder
        } catch {
            return .default
        }
    }

    public func saveFinderPreference(_ preference: FinderPreference) throws {
        let wrapper = SettingsWrapper(finder: preference)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(wrapper)
        try data.write(to: settingsURL, options: .atomic)
    }
}

private struct SettingsWrapper: Codable {
    var finder: FinderPreference
}
