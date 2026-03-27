import XCTest

@testable import GotoNativeCore

final class TerminalScriptBuilderTests: XCTestCase {
    func testShellCommandQuotesSpacesAndSingleQuotes() {
        let builder = TerminalScriptBuilder()
        let command = builder.shellCommand(forDirectory: "/tmp/alpha beta/it's-here")

        XCTAssertEqual(command, "cd -- '/tmp/alpha beta/it'\"'\"'s-here'")
    }

    func testTerminalAppleScriptUsesFrontWindowFallbackStructure() {
        let builder = TerminalScriptBuilder(terminalApp: .terminal)
        let script = builder.appleScript(forDirectory: "/tmp/demo")

        XCTAssertTrue(script.contains("tell application \"Terminal\""))
        XCTAssertTrue(script.contains("if not (exists front window) then"))
        XCTAssertTrue(script.contains("do script \"cd -- '/tmp/demo'\""))
        XCTAssertTrue(script.contains("do script \"cd -- '/tmp/demo'\" in front window"))
    }

    func testTerminalAppleScriptEscapesQuotesInsideShellCommand() {
        let builder = TerminalScriptBuilder(terminalApp: .terminal)
        let script = builder.appleScript(forDirectory: "/tmp/it's here")

        XCTAssertTrue(script.contains("it'\\\"'\\\"'s here"))
    }

    func testITermAppleScriptTargetsITermApp() {
        let builder = TerminalScriptBuilder(terminalApp: .iterm2)
        let script = builder.appleScript(forDirectory: "/tmp/demo")

        XCTAssertTrue(script.contains("tell application \"iTerm\""))
        XCTAssertTrue(script.contains("create window with default profile"))
        XCTAssertTrue(script.contains("create tab with default profile"))
        XCTAssertTrue(script.contains("write text \"cd -- '/tmp/demo'\""))
    }

    func testOpenCommandForEachTerminal() {
        let cases: [(TerminalApp, String)] = [
            (.terminal, "Terminal"),
            (.iterm2, "iTerm2"),
            (.warp, "Warp"),
            (.ghostty, "Ghostty"),
            (.alacritty, "Alacritty"),
            (.kitty, "Kitty"),
        ]

        for (app, expectedName) in cases {
            let builder = TerminalScriptBuilder(terminalApp: app)
            let args = builder.openCommand(forDirectory: "/tmp/demo")
            XCTAssertEqual(args, ["-a", expectedName, "/tmp/demo"], "Failed for \(app)")
        }
    }

    func testDefaultBuilderUsesTerminalApp() {
        let builder = TerminalScriptBuilder()
        XCTAssertEqual(builder.terminalApp, .terminal)
    }
}
