import AppKit
import FinderSync

final class GotoFinderSyncExtension: FIFinderSync {
    private let controller = FIFinderSyncController.default()
    private let launcher = TerminalLauncher(detector: TerminalAppDetector(preference: .auto))
    private let presenter = TerminalErrorPresenter()
    private var launchDebouncer = LaunchDebouncer()

    override init() {
        super.init()

        let homeDirectory = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        controller.directoryURLs = [URL(fileURLWithPath: homeDirectory, isDirectory: true)]
    }

    override var toolbarItemName: String {
        "goto"
    }

    override var toolbarItemToolTip: String {
        "Open the current Finder folder in Terminal"
    }

    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "terminal", accessibilityDescription: "goto")
            ?? NSImage(named: NSImage.folderName)!
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "goto")

        guard menuKind == .toolbarItemMenu else {
            return menu
        }

        guard let folderURL = selectedFinderFolderURL() else {
            menu.addItem(disabledItem("No folder selected in Finder"))
            return menu
        }

        if launchDebouncer.shouldLaunch(path: folderURL.path) {
            launch(folderURL: folderURL)
        }

        let item = NSMenuItem(
            title: "Open in Terminal",
            action: nil,
            keyEquivalent: ""
        )
        item.isEnabled = false
        menu.addItem(item)
        return menu
    }

    private func selectedFinderFolderURL() -> URL? {
        FinderFolderResolver.resolvedFolderURL(
            selectedItemURLs: controller.selectedItemURLs(),
            targetedURL: controller.targetedURL()
        )
    }

    private func launch(folderURL: URL) {
        do {
            let request = TerminalLaunchRequest(
                directory: ValidatedDirectory(path: folderURL.path, name: folderURL.lastPathComponent)
            )
            try launcher.launch(request)
        } catch let error as TerminalLaunchError {
            present(presenter.present(launchError: error))
        } catch {
            present(UserFacingError(title: "goto Error", message: error.localizedDescription))
        }
    }

    private func present(_ error: UserFacingError) {
        let alert = NSAlert()
        alert.messageText = error.title
        alert.informativeText = error.message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
