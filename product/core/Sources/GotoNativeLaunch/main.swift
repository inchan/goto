import Darwin
import Foundation

import GotoNativeCore

private func write(_ value: String, to handle: FileHandle) {
    guard !value.isEmpty else {
        return
    }

    let text = value.hasSuffix("\n") ? value : "\(value)\n"
    handle.write(Data(text.utf8))
}

let command = TerminalLaunchCommand()
let result = command.run(arguments: CommandLine.arguments)

write(result.stdout, to: .standardOutput)
write(result.stderr, to: .standardError)

exit(result.exitCode)
