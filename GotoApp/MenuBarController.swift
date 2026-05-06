import AppKit

@MainActor
final class MenuBarController: NSObject {

    private var statusItem: NSStatusItem?
    private var tagToPath: [Int: String] = [:]

    private var fileSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    func update() {
        if GotoSettings.isMenuBarEnabled() {
            installIfNeeded()
        } else {
            removeStatusItem()
        }
    }

    private func installIfNeeded() {
        guard statusItem == nil else {
            statusItem?.menu = buildMenu()
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            let img = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Goto")
            img?.size = NSSize(width: 18, height: 18)
            img?.isTemplate = true
            button.image = img
            button.toolTip = "Goto"
        }

        item.menu = buildMenu()
        statusItem = item

        startWatchingProjectsFile()
    }

    private func removeStatusItem() {
        stopWatchingProjectsFile()
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        tagToPath.removeAll()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        tagToPath.removeAll()
        let paths = GotoProjectStore.load()

        if paths.isEmpty {
            let empty = NSMenuItem(title: "등록된 프로젝트 없음 (goto --add 사용)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            let config = GotoSettings.cliConfig()
            let ordered = GotoProjectList.orderedProjects(paths, config: config)
            let recents = Array(ordered.displayProjects.prefix(ordered.recentCount))
            let remainingPaths = Array(ordered.displayProjects.dropFirst(ordered.recentCount))
            var tag = 1

            for path in recents {
                addProjectItem(path, to: menu, tag: &tag)
            }

            if GotoSettings.isMenuBarProjectGroupingEnabled() {
                let groups = parentGroups(for: remainingPaths)

                if !recents.isEmpty && !groups.isEmpty {
                    menu.addItem(.separator())
                }

                for group in groups {
                    let parentItem = NSMenuItem(title: group.parent, action: nil, keyEquivalent: "")
                    parentItem.toolTip = group.parentPath
                    let submenu = NSMenu()

                    for path in group.projects {
                        addProjectItem(path, to: submenu, tag: &tag)
                    }

                    parentItem.submenu = submenu
                    menu.addItem(parentItem)
                }
            } else {
                if !recents.isEmpty && !remainingPaths.isEmpty {
                    menu.addItem(.separator())
                }

                for path in remainingPaths {
                    addProjectItem(path, to: menu, tag: &tag)
                }
            }
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        return menu
    }

    @objc private func openProject(_ sender: NSMenuItem) {
        guard let path = tagToPath[sender.tag] else { return }
        GotoProjectList.recordRecentProject(path, availableProjects: GotoProjectStore.load())
        _ = TerminalLauncher.open(
            preference: GotoSettings.defaultTerminalPreference(),
            path: path
        )
    }

    @objc private func openSettings() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.showSetupWindow()
        }
    }

    private func startWatchingProjectsFile() {
        stopWatchingProjectsFile()

        let url = GotoProjectStore.storeURL
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        fileDescriptor = fd
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.statusItem?.menu = self.buildMenu()
                if source.data.contains(.delete) || source.data.contains(.rename) {
                    self.startWatchingProjectsFile()
                }
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        fileSource = source
    }

    private func stopWatchingProjectsFile() {
        fileSource?.cancel()
        fileSource = nil
        fileDescriptor = -1
    }

    private func addProjectItem(_ path: String, to menu: NSMenu, tag: inout Int) {
        tagToPath[tag] = path

        let item = NSMenuItem(title: GotoProjectList.displayItem(for: path).name, action: #selector(openProject(_:)), keyEquivalent: "")
        item.target = self
        item.toolTip = path
        item.tag = tag
        menu.addItem(item)
        tag += 1
    }

    private func parentGroups(
        for paths: [String]
    ) -> [(parent: String, parentPath: String, projects: [String])] {
        var groups: [(parent: String, parentPath: String, projects: [String])] = []

        for path in paths {
            let parentURL = URL(fileURLWithPath: path).deletingLastPathComponent()
            let parentPath = GotoProjectList.displayPath(for: parentURL.path)
            let parent = GotoProjectList.displayItem(for: path).parent
            if groups.last?.parentPath == parentPath {
                groups[groups.count - 1].projects.append(path)
            } else {
                groups.append((parent: parent, parentPath: parentPath, projects: [path]))
            }
        }

        return groups
    }

}

extension MenuBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        let fresh = buildMenu()
        menu.removeAllItems()
        for item in fresh.items {
            fresh.removeItem(item)
            menu.addItem(item)
        }
    }
}
