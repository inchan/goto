import AppKit
import Foundation

public protocol TerminalAppDetecting: Sendable {
    func detect() -> TerminalApp
}

public final class TerminalAppDetector: TerminalAppDetecting, Sendable {
    private let preference: TerminalPreference

    public init(preference: TerminalPreference = .auto) {
        self.preference = preference
    }

    public func detect() -> TerminalApp {
        switch preference {
        case .specific(let app):
            return app.isInstalled ? app : detectAuto()
        case .auto:
            return detectAuto()
        }
    }

    private func detectAuto() -> TerminalApp {
        if let running = detectFromRunningApps() {
            return running
        }
        return .terminal
    }

    private func detectFromRunningApps() -> TerminalApp? {
        let apps = NSWorkspace.shared.runningApplications
        var candidates: [(TerminalApp, Date?)] = []

        for app in apps where app.activationPolicy == .regular {
            guard let bundleID = app.bundleIdentifier else { continue }
            if let terminal = TerminalApp.from(bundleIdentifier: bundleID) {
                candidates.append((terminal, app.launchDate))
            }
        }

        if candidates.isEmpty {
            return nil
        }

        if candidates.count == 1 {
            return candidates[0].0
        }

        return candidates
            .sorted { ($0.1 ?? .distantPast) > ($1.1 ?? .distantPast) }
            .first?.0
    }
}

public struct FixedTerminalAppDetector: TerminalAppDetecting, Sendable {
    public let app: TerminalApp

    public init(_ app: TerminalApp) {
        self.app = app
    }

    public func detect() -> TerminalApp {
        app
    }
}
