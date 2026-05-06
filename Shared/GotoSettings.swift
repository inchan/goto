import Foundation

enum TerminalPreference: String, CaseIterable {
    case terminal
    case ghostty

    var displayName: String {
        switch self {
        case .terminal:
            return "Terminal"
        case .ghostty:
            return "Ghostty"
        }
    }

    var settingsTitle: String {
        switch self {
        case .terminal:
            return "Default Terminal"
        case .ghostty:
            return "Ghostty"
        }
    }

    var openMenuTitle: String {
        "Open in \(displayName)"
    }
}

enum ExistingTerminalBehavior: String, CaseIterable {
    case tab
    case window

    var settingsTitle: String {
        switch self {
        case .tab:
            return "New Tab"
        case .window:
            return "New Window"
        }
    }
}

enum GotoSettings {
    private static let extensionBundleIdentifier = "com.inchan.goto.findersync"
    private static let defaultTerminalPreferenceKey = "DefaultTerminalPreference"
    private static let existingTerminalBehaviorKey = "ExistingTerminalBehavior"
    nonisolated(unsafe) static var userDefaults: UserDefaults = .standard

    static func availableTerminalPreferences() -> [TerminalPreference] {
        if TerminalLauncher.isGhosttyAvailable() {
            return [.terminal, .ghostty]
        }

        return [.terminal]
    }

    static func defaultTerminalPreference() -> TerminalPreference {
        let availablePreferences = availableTerminalPreferences()

        if let storedPreference = storedTerminalPreference(),
           availablePreferences.contains(storedPreference) {
            return storedPreference
        }

        return availablePreferences.contains(.ghostty) ? .ghostty : .terminal
    }

    static func saveDefaultTerminalPreference(_ preference: TerminalPreference) {
        userDefaults.set(preference.rawValue, forKey: defaultTerminalPreferenceKey)

        var preferences = readPreferencesFile()
        preferences[defaultTerminalPreferenceKey] = preference.rawValue
        writePreferencesFile(preferences)
    }

    static func existingTerminalBehavior() -> ExistingTerminalBehavior {
        if let value = readPreferencesFile()[existingTerminalBehaviorKey] as? String,
           let behavior = ExistingTerminalBehavior(rawValue: value) {
            return behavior
        }

        if let value = userDefaults.string(forKey: existingTerminalBehaviorKey),
           let behavior = ExistingTerminalBehavior(rawValue: value) {
            return behavior
        }

        return .tab
    }

    static func saveExistingTerminalBehavior(_ behavior: ExistingTerminalBehavior) {
        userDefaults.set(behavior.rawValue, forKey: existingTerminalBehaviorKey)

        var preferences = readPreferencesFile()
        preferences[existingTerminalBehaviorKey] = behavior.rawValue
        writePreferencesFile(preferences)
    }

    private static func storedTerminalPreference() -> TerminalPreference? {
        if let value = readPreferencesFile()[defaultTerminalPreferenceKey] as? String,
           let preference = TerminalPreference(rawValue: value) {
            return preference
        }

        if let value = userDefaults.string(forKey: defaultTerminalPreferenceKey) {
            return TerminalPreference(rawValue: value)
        }

        return nil
    }

    private static func readPreferencesFile() -> [String: Any] {
        guard let data = try? Data(contentsOf: preferencesFileURL),
              let propertyList = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let preferences = propertyList as? [String: Any] else {
            return [:]
        }

        return preferences
    }

    private static func writePreferencesFile(_ preferences: [String: Any]) {
        let directoryURL = preferencesFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        guard let data = try? PropertyListSerialization.data(fromPropertyList: preferences, format: .xml, options: 0) else {
            return
        }

        try? data.write(to: preferencesFileURL, options: .atomic)
    }

    private static var preferencesFileURL: URL {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let containerSuffix = "/Library/Containers/\(extensionBundleIdentifier)/Data"

        if homeURL.path.hasSuffix(containerSuffix) {
            return homeURL
                .appendingPathComponent("Library")
                .appendingPathComponent("Preferences")
                .appendingPathComponent("\(extensionBundleIdentifier).plist")
        }

        return homeURL
            .appendingPathComponent("Library")
            .appendingPathComponent("Containers")
            .appendingPathComponent(extensionBundleIdentifier)
            .appendingPathComponent("Data")
            .appendingPathComponent("Library")
            .appendingPathComponent("Preferences")
            .appendingPathComponent("\(extensionBundleIdentifier).plist")
    }
}
