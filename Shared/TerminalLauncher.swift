import AppKit
import ApplicationServices
import Foundation

enum TerminalLauncher {
    static func isGhosttyAvailable() -> Bool {
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.mitchellh.ghostty") != nil {
            return true
        }

        return runAppleScript("id of application \"Ghostty\"").succeeded
    }

    @discardableResult
    static func open(preference: TerminalPreference = .ghostty, path requestedPath: String? = nil) -> Bool {
        let workingDirectory = normalizedDirectory(requestedPath) ?? finderDirectory() ?? FileManager.default.homeDirectoryForCurrentUser.path
        let existingBehavior = GotoSettings.existingTerminalBehavior()
        appendDebugLine("open requestedPath=\(requestedPath ?? "nil") workingDirectory=\(workingDirectory) preference=\(preference.rawValue) existingBehavior=\(existingBehavior.rawValue)")

        switch preference {
        case .ghostty:
            if openGhostty(at: workingDirectory, existingBehavior: existingBehavior) {
                return true
            }

            let result = openTerminal(at: workingDirectory, existingBehavior: existingBehavior)
            appendDebugLine("open fallbackTerminal result=\(result)")
            return result
        case .terminal:
            return openTerminal(at: workingDirectory, existingBehavior: existingBehavior)
        }
    }

    private static func normalizedDirectory(_ path: String?) -> String? {
        guard let path, !path.isEmpty else {
            return nil
        }

        var isDirectory = ObjCBool(false)
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return path
            }

            return URL(fileURLWithPath: path).deletingLastPathComponent().path
        }

        return nil
    }

    private static func finderDirectory() -> String? {
        let script = """
        tell application "Finder"
            if (count of Finder windows) > 0 then
                set targetFolder to target of front Finder window as alias
            else
                set targetFolder to desktop as alias
            end if

            POSIX path of targetFolder
        end tell
        """

        let result = runAppleScript(script)
        guard result.succeeded else {
            return nil
        }

        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedDirectory(path)
    }

    private static func openGhostty(at path: String, existingBehavior: ExistingTerminalBehavior) -> Bool {
        let exists = runAppleScript("id of application \"Ghostty\"")
        appendDebugLine("ghostty exists \(exists.summary)")
        guard exists.succeeded else {
            return false
        }

        let isRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.mitchellh.ghostty"
        }
        let launchMode = isRunning && existingBehavior == .tab ? "tab" : "window"
        let pathLiteral = appleScriptStringLiteral(path)
        let modeLiteral = appleScriptStringLiteral(launchMode)

        let script = """
        set targetPath to \(pathLiteral)
        set launchMode to \(modeLiteral)

        tell application "Ghostty"
            set cfg to new surface configuration
            set initial working directory of cfg to targetPath

            if launchMode is "tab" then
                activate
                if (count of windows) > 0 then
                    new tab in front window with configuration cfg
                else
                    new window with configuration cfg
                end if
            else
                new window with configuration cfg
                activate
            end if
        end tell
        """

        let result = runAppleScript(script)
        appendDebugLine("ghostty open running=\(isRunning) mode=\(launchMode) \(result.summary)")
        return result.succeeded
    }

    private static func openTerminal(at path: String, existingBehavior: ExistingTerminalBehavior) -> Bool {
        let isRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.Terminal"
        }
        let pathLiteral = appleScriptStringLiteral(path)

        if isRunning && existingBehavior == .tab, openTerminalTab(at: pathLiteral) {
            return true
        }

        if openTerminalWindow(at: pathLiteral) {
            return true
        }

        return openTerminalViaLaunchServices(at: path)
    }

    private static func openTerminalWindow(at pathLiteral: String) -> Bool {
        let script = """
        set targetPath to \(pathLiteral)

        tell application "Terminal"
            activate
            do script "cd " & quoted form of targetPath
        end tell
        """

        let result = runAppleScript(script)
        appendDebugLine("terminal window applescript \(result.summary)")
        return result.succeeded
    }

    private static func openTerminalTab(at pathLiteral: String) -> Bool {
        guard let terminalApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.Terminal" }) else {
            appendDebugLine("terminal tab skipped reason=terminal-not-running")
            return false
        }

        guard AXIsProcessTrustedWithOptions([
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary) else {
            appendDebugLine("terminal tab skipped reason=accessibility-not-trusted")
            return false
        }

        terminalApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        Thread.sleep(forTimeInterval: 0.15)

        guard sendNewTabShortcut(to: terminalApp.processIdentifier) else {
            appendDebugLine("terminal tab skipped reason=keyboard-event-failed")
            return false
        }

        Thread.sleep(forTimeInterval: 0.35)

        let script = """
        set targetPath to \(pathLiteral)

        tell application "Terminal"
            do script "cd " & quoted form of targetPath in selected tab of front window
        end tell
        """

        let result = runAppleScript(script)
        appendDebugLine("terminal tab applescript \(result.summary)")
        return result.succeeded
    }

    private static func openTerminalViaLaunchServices(at path: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", path]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            appendDebugLine("terminal launchservices error=\(oneLine(String(describing: error)))")
            return false
        }

        let succeeded = process.terminationStatus == 0
        appendDebugLine("terminal launchservices status=\(process.terminationStatus) result=\(succeeded)")
        return succeeded
    }

    private static func sendNewTabShortcut(to processIdentifier: pid_t) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 17, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 17, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.postToPid(processIdentifier)
        keyUp.postToPid(processIdentifier)
        return true
    }

    private static func appleScriptStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func runAppleScript(_ source: String) -> AppleScriptResult {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return AppleScriptResult(succeeded: false, output: "", error: "failed to create NSAppleScript")
        }

        let descriptor = script.executeAndReturnError(&error)
        if let error {
            return AppleScriptResult(succeeded: false, output: descriptor.stringValue ?? "", error: String(describing: error))
        }

        return AppleScriptResult(succeeded: true, output: descriptor.stringValue ?? "", error: "")
    }

    private static func appendDebugLine(_ line: String) {
        let logURL = debugLogURL
        let entry = "\(Date()) \(line)\n"

        do {
            try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: logURL.path),
               let handle = try? FileHandle(forWritingTo: logURL) {
                defer {
                    try? handle.close()
                }

                try handle.seekToEnd()
                try handle.write(contentsOf: Data(entry.utf8))
            } else {
                try entry.write(to: logURL, atomically: true, encoding: .utf8)
            }
        } catch {
            // Debug logging must never block opening the terminal.
        }
    }

    private static var debugLogURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Containers")
            .appendingPathComponent("com.inchan.goto.findersync")
            .appendingPathComponent("Data")
            .appendingPathComponent("Library")
            .appendingPathComponent("Caches")
            .appendingPathComponent("GotoLauncherDebug.log")
    }

    private static func oneLine(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        guard normalized.count > 500 else {
            return normalized
        }

        return "\(normalized.prefix(497))..."
    }
}

private struct AppleScriptResult {
    let succeeded: Bool
    let output: String
    let error: String

    var summary: String {
        let outputText = output.isEmpty ? "empty" : oneLine(output)
        let errorText = error.isEmpty ? "empty" : oneLine(error)
        return "succeeded=\(succeeded) output=\(outputText) error=\(errorText)"
    }

    private func oneLine(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        guard normalized.count > 500 else {
            return normalized
        }

        return "\(normalized.prefix(497))..."
    }
}
