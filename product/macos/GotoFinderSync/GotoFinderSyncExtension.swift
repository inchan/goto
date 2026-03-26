import AppKit
import FinderSync

final class GotoFinderSyncExtension: FIFinderSync {
    private let controller = FIFinderSyncController.default()
    private var lastAutomaticLaunch: (path: String, instant: Date)?
    private var observedDirectories: [URL] = []
    private let currentFinderFolderSentinel = "__goto_current_finder_folder__"

    // Received from host app via DistributedNotificationCenter
    private var cachedProjectPaths: [String] = []
    private var cachedClickMode: FinderClickMode = .directPlusList
    private var cachedEnabled: Bool = true

    // Paths indexed by menu item tag for action dispatch
    private var menuTagToPath: [Int: String] = [:]
    private var nextTag = 1

    override init() {
        super.init()
        // Use real home from environment — homeDirectoryForCurrentUser returns sandbox container
        let home = ProcessInfo.processInfo.environment["HOME"] ?? "/Users"
        controller.directoryURLs = [URL(fileURLWithPath: home, isDirectory: true)]

        let center = DistributedNotificationCenter.default()

        center.addObserver(
            self, selector: #selector(handleProjectListUpdate(_:)),
            name: .gotoProjectListUpdated, object: nil,
            suspensionBehavior: .deliverImmediately
        )
        center.addObserver(
            self, selector: #selector(handlePreferenceUpdate(_:)),
            name: .gotoFinderPreferenceUpdated, object: nil,
            suspensionBehavior: .deliverImmediately
        )

        // Tell host we're ready
        center.postNotificationName(
            .gotoExtensionReady, object: nil, userInfo: nil,
            options: [.deliverImmediately]
        )
    }

    override var toolbarItemName: String { "goto" }

    override var toolbarItemToolTip: String {
        "goto: open the selected folder or a saved project in Terminal"
    }

    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "terminal", accessibilityDescription: "goto")
            ?? NSImage(named: NSImage.folderName)!
    }

    override func beginObservingDirectory(at url: URL) {
        observedDirectories.removeAll { $0.path == url.path }
        observedDirectories.append(url)
        postNotification(.gotoFinderObservedDirectoryBegan, path: url.path)
    }

    override func endObservingDirectory(at url: URL) {
        observedDirectories.removeAll { $0.path == url.path }
        postNotification(.gotoFinderObservedDirectoryEnded, path: url.path)
    }

    // MARK: - IPC from Host

    @objc private func handleProjectListUpdate(_ notification: Notification) {
        guard let encoded = notification.userInfo?[FinderSyncBroadcast.projectsKey] as? String else { return }
        cachedProjectPaths = FinderSyncBroadcast.decodeProjects(encoded)
    }

    @objc private func handlePreferenceUpdate(_ notification: Notification) {
        if let raw = notification.userInfo?[FinderSyncBroadcast.clickModeKey] as? String {
            cachedClickMode = FinderClickMode(rawValue: raw) ?? .directPlusList
        }
        if let enabled = notification.userInfo?[FinderSyncBroadcast.enabledKey] as? Bool {
            cachedEnabled = enabled
        }
    }

    // MARK: - Toolbar Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        menuTagToPath = [:]
        nextTag = 1

        guard menuKind == .toolbarItemMenu, cachedEnabled else {
            if !cachedEnabled {
                addDisabledItem(menu, "goto is disabled")
            }
            return menu
        }

        // Re-request if cache empty
        if cachedProjectPaths.isEmpty {
            DistributedNotificationCenter.default().postNotificationName(
                .gotoExtensionReady, object: nil, userInfo: nil,
                options: [.deliverImmediately]
            )
        }

        let clickMode = cachedClickMode
        let directory = selectedDirectoryURL()

        // === Direct mode: auto-open immediately ===
        if clickMode == .direct {
            if let dir = directory {
                launchPath(dir.path)
                addDisabledItem(menu, "Opened \(dir.lastPathComponent) in Terminal")
            } else {
                launchCurrentFinderFolder()
                addDisabledItem(menu, "Opened in Terminal")
            }
            return menu
        }

        // === List / DirectPlusList: show clickable menu ===
        if let dir = directory {
            addClickableItem(menu, "Open \(dir.lastPathComponent) in Terminal", path: dir.path)
        } else {
            addClickableItem(menu, "Open Terminal", path: currentFinderFolderSentinel)
        }

        if !cachedProjectPaths.isEmpty {
            menu.addItem(.separator())
            for path in cachedProjectPaths.prefix(12) {
                let name = URL(fileURLWithPath: path).lastPathComponent
                addClickableItem(menu, name, path: path)
            }
        }

        return menu
    }

    // MARK: - Menu Construction

    private func addDisabledItem(_ menu: NSMenu, _ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addClickableItem(_ menu: NSMenu, _ title: String, path: String) {
        let tag = nextTag
        nextTag += 1
        menuTagToPath[tag] = path

        let item = NSMenuItem(title: title, action: #selector(menuItemClicked(_:)), keyEquivalent: "")
        item.target = self
        item.tag = tag
        menu.addItem(item)
    }

    // MARK: - Menu Actions

    @objc func menuItemClicked(_ sender: NSMenuItem) {
        guard let path = menuTagToPath[sender.tag] else { return }
        if path == currentFinderFolderSentinel {
            launchCurrentFinderFolder()
        } else {
            launchPath(path)
        }
    }

    // MARK: - Launch

    private func launchPath(_ path: String) {
        let now = Date()
        if let prev = lastAutomaticLaunch, prev.path == path,
           now.timeIntervalSince(prev.instant) < 1.0 { return }
        lastAutomaticLaunch = (path, now)
        postNotification(.gotoFinderLaunchRequested, path: path)
    }

    private func launchCurrentFinderFolder() {
        let now = Date()
        if let prev = lastAutomaticLaunch, prev.path == currentFinderFolderSentinel,
           now.timeIntervalSince(prev.instant) < 1.0 { return }
        lastAutomaticLaunch = (currentFinderFolderSentinel, now)
        DistributedNotificationCenter.default().postNotificationName(
            .gotoFinderLaunchRequested, object: nil,
            userInfo: [FinderLaunchNotification.modeKey: FinderLaunchNotification.currentFinderFolderMode],
            options: [.deliverImmediately]
        )
    }

    // MARK: - Helpers

    private func postNotification(_ name: Notification.Name, path: String) {
        DistributedNotificationCenter.default().postNotificationName(
            name, object: nil,
            userInfo: [FinderLaunchNotification.pathKey: path],
            options: [.deliverImmediately]
        )
    }

    private func selectedDirectoryURL() -> URL? {
        // Trust Finder Sync API URLs directly — sandbox prevents FileManager checks
        if let urls = controller.selectedItemURLs(), urls.count == 1 {
            return urls[0]
        }
        if let url = controller.targetedURL() {
            return url
        }
        if let url = observedDirectories.last {
            return url
        }
        return nil
    }
}
