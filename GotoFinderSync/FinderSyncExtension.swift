import AppKit
import FinderSync
import Foundation

final class FinderSyncExtension: FIFinderSync {
    private let extensionBundle = Bundle(for: FinderSyncExtension.self)

    // Finder Sync ↔ Finder process 경계에서 representedObject가 보존되지 않으므로
    // tag(보존됨) + 로컬 dictionary로 path 전달.
    private static let openTerminalTag = 1
    private static let worktreesTag = 2
    private let menuPayloadsLock = NSLock()
    private var menuPayloads: [Int: String] = [:]

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override var toolbarItemName: String {
        "Goto"
    }

    override var toolbarItemToolTip: String {
        "Open this Finder location in your selected terminal"
    }

    override var toolbarItemImage: NSImage {
        if let image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Goto") {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }

        if let iconURL = extensionBundle.url(forResource: "applet", withExtension: "icns"),
           let image = NSImage(contentsOf: iconURL) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }

        return NSImage()
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let menu = NSMenu(title: "Goto")
        menu.autoenablesItems = false
        let path = preferredPath(for: menuKind)

        menuPayloadsLock.lock()
        menuPayloads.removeAll()
        if let path, !path.isEmpty {
            menuPayloads[Self.openTerminalTag] = path
            menuPayloads[Self.worktreesTag] = path
        }
        menuPayloadsLock.unlock()

        let openItem = NSMenuItem(title: "Open in Terminal", action: #selector(openTerminal(_:)), keyEquivalent: "")
        openItem.target = self
        openItem.tag = Self.openTerminalTag
        openItem.isEnabled = true
        menu.addItem(openItem)

        let worktreeItem = NSMenuItem(title: "Worktrees…", action: #selector(openWorktreesWindow(_:)), keyEquivalent: "")
        worktreeItem.target = self
        worktreeItem.tag = Self.worktreesTag
        worktreeItem.isEnabled = (path != nil)
        menu.addItem(worktreeItem)

        return menu
    }

    private func resolveClickedPath(from sender: NSMenuItem) -> String? {
        menuPayloadsLock.lock()
        let stored = menuPayloads[sender.tag]
        menuPayloadsLock.unlock()
        if let stored, !stored.isEmpty {
            return stored
        }
        return preferredPath(for: .toolbarItemMenu)
    }

    @objc private func openTerminal(_ sender: NSMenuItem) {
        let path = resolveClickedPath(from: sender)
        guard let url = GotoLaunchRequest.url(path: path) else { return }
        _ = NSWorkspace.shared.open(url)
    }

    @objc private func openWorktreesWindow(_ sender: NSMenuItem) {
        guard let path = resolveClickedPath(from: sender), !path.isEmpty,
              let url = GotoLaunchRequest.worktreesURL(path: path) else {
            return
        }
        _ = NSWorkspace.shared.open(url)
    }

    private func preferredPath(for menuKind: FIMenuKind) -> String? {
        let controller = FIFinderSyncController.default()

        switch menuKind {
        case .contextualMenuForItems, .contextualMenuForSidebar:
            if let selectedURL = controller.selectedItemURLs()?.first {
                return directoryPath(for: selectedURL)
            }
            if let targetedURL = controller.targetedURL() {
                return directoryPath(for: targetedURL)
            }
        case .contextualMenuForContainer:
            if let targetedURL = controller.targetedURL() {
                return directoryPath(for: targetedURL)
            }
        case .toolbarItemMenu:
            if let targetedURL = controller.targetedURL() {
                return directoryPath(for: targetedURL)
            }
            if let selectedURL = controller.selectedItemURLs()?.first {
                return directoryPath(for: selectedURL)
            }
            return frontFinderDirectoryPath()
        @unknown default:
            return frontFinderDirectoryPath()
        }

        return frontFinderDirectoryPath()
    }

    private func directoryPath(for url: URL) -> String {
        var isDirectory = ObjCBool(false)
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return url.path
        }
        return url.deletingLastPathComponent().path
    }

    private func frontFinderDirectoryPath() -> String? {
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

        var error: NSDictionary?
        guard let result = NSAppleScript(source: script)?.executeAndReturnError(&error),
              error == nil,
              let path = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }

        return directoryPath(for: URL(fileURLWithPath: path))
    }
}
