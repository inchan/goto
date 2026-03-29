import AppKit
import Foundation

public enum TerminalApp: String, Equatable, Sendable, CaseIterable, Identifiable {
    case terminal
    case iterm2
    case warp
    case ghostty
    case alacritty
    case kitty

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .terminal:  return "Terminal"
        case .iterm2:    return "iTerm2"
        case .warp:      return "Warp"
        case .ghostty:   return "Ghostty"
        case .alacritty: return "Alacritty"
        case .kitty:     return "Kitty"
        }
    }

    public var bundleIdentifier: String {
        switch self {
        case .terminal:  return "com.apple.Terminal"
        case .iterm2:    return "com.googlecode.iterm2"
        case .warp:      return "dev.warp.Warp-Stable"
        case .ghostty:   return "com.mitchellh.ghostty"
        case .alacritty: return "org.alacritty"
        case .kitty:     return "net.kovidgoyal.kitty"
        }
    }

    public var supportsAppleScript: Bool {
        switch self {
        case .iterm2: return true
        default: return false
        }
    }

    public var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    public static var installedApps: [TerminalApp] {
        allCases.filter(\.isInstalled)
    }

    public static func from(bundleIdentifier: String) -> TerminalApp? {
        allCases.first { $0.bundleIdentifier == bundleIdentifier }
    }
}

public enum TerminalPreference: Equatable, Sendable {
    case auto
    case specific(TerminalApp)

    public var rawValue: String {
        switch self {
        case .auto: return "auto"
        case .specific(let app): return app.rawValue
        }
    }

    public init(rawValue: String) {
        if rawValue == "auto" {
            self = .auto
        } else if let app = TerminalApp(rawValue: rawValue) {
            self = .specific(app)
        } else {
            self = .auto
        }
    }

    public static let userDefaultsKey = "terminalPreference"

    public static func load(from defaults: UserDefaults = .standard) -> TerminalPreference {
        guard let raw = defaults.string(forKey: userDefaultsKey) else { return .auto }
        return TerminalPreference(rawValue: raw)
    }

    public func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.userDefaultsKey)
    }
}
