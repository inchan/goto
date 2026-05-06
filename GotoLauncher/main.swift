import AppKit

final class LauncherDelegate: NSObject, NSApplicationDelegate {
    private var didHandleOpenRequest = false
    private var fallbackOpenWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.didHandleOpenRequest else {
                return
            }

            self.openTerminal(path: nil)
        }

        fallbackOpenWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        didHandleOpenRequest = true
        fallbackOpenWorkItem?.cancel()

        let path = urls.compactMap { GotoLaunchRequest.path(from: $0) }.first
        openTerminal(path: path)
    }

    private func openTerminal(path: String?) {
        TerminalLauncher.open(preference: GotoSettings.defaultTerminalPreference(), path: path)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = LauncherDelegate()

app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
