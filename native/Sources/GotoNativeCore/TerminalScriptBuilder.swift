import Foundation

public struct TerminalScriptBuilder: Sendable {
    public let terminalApp: TerminalApp

    public init(terminalApp: TerminalApp = .terminal) {
        self.terminalApp = terminalApp
    }

    public func shellCommand(forDirectory directory: String) -> String {
        "cd -- \(quoteForShell(directory))"
    }

    public func appleScript(forDirectory directory: String) -> String {
        switch terminalApp {
        case .terminal:
            return terminalAppleScript(forDirectory: directory)
        case .iterm2:
            return iTermAppleScript(forDirectory: directory)
        case .warp, .ghostty, .alacritty, .kitty:
            fatalError("\(terminalApp) does not support AppleScript — use openCommand instead")
        }
    }

    public func openCommand(forDirectory directory: String) -> [String] {
        ["-a", terminalApp.displayName, directory]
    }

    public func quoteForShell(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\"'\"'")
        return "'\(escaped)'"
    }

    // MARK: - Terminal.app

    private func terminalAppleScript(forDirectory directory: String) -> String {
        let command = escapeForAppleScript(shellCommand(forDirectory: directory))

        return """
        tell application "Terminal"
            activate
            if not (exists front window) then
                do script "\(command)"
            else
                do script "\(command)" in front window
            end if
        end tell
        """
    }

    // MARK: - iTerm2

    private func iTermAppleScript(forDirectory directory: String) -> String {
        let command = escapeForAppleScript(shellCommand(forDirectory: directory))

        return """
        tell application "iTerm"
            activate
            if (count of windows) is 0 then
                create window with default profile
                tell current session of current window
                    write text "\(command)"
                end tell
            else
                tell current window
                    create tab with default profile
                    tell current session
                        write text "\(command)"
                    end tell
                end tell
            end if
        end tell
        """
    }

    // MARK: - Escaping

    private func escapeForAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
