import AppKit
import SwiftUI

@main
struct GotoFinderApp: App {
    @NSApplicationDelegateAdaptor(GotoFinderAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class GotoFinderAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        FinderLaunchBridge.shared.start()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            FinderLaunchBridge.shared.handle(url: url)
        }
    }
}
