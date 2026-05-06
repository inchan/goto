import AppKit
import FinderSync

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var terminalStatusLabel: NSTextField?

    private var menuBarController: MenuBarController?
    private var openWorktreeWindows: [WorktreeWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        menuBarController = MenuBarController()
        menuBarController?.update()
        showSetupWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return !GotoSettings.isMenuBarEnabled()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleURL(url)
        }
    }

    private func handleURL(_ url: URL) {
        guard let action = GotoLaunchRequest.parse(url: url) else { return }

        switch action {
        case .openTerminal(let path):
            _ = TerminalLauncher.open(
                preference: GotoSettings.defaultTerminalPreference(),
                path: path
            )
        case .showWorktrees(let repoPath):
            showWorktreesWindow(for: repoPath)
        }
    }

    private func showWorktreesWindow(for repoPath: String) {
        let gitURL = WorktreeService.defaultGitExecutableURL

        DispatchQueue.global(qos: .userInitiated).async {
            let result = WorktreeService.worktrees(at: repoPath, gitExecutable: gitURL)

            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    switch result {
                    case .success(let entries):
                        self.presentWorktreeWindow(repoPath: repoPath, entries: entries, errorMessage: nil)
                    case .failure(let error):
                        self.presentWorktreeWindow(repoPath: repoPath, entries: [], errorMessage: Self.localizedMessage(for: error))
                    }
                }
            }
        }
    }

    private func presentWorktreeWindow(repoPath: String, entries: [GotoWorktreeEntry], errorMessage: String?) {
        let controller = WorktreeWindowController(
            repoPath: repoPath,
            entries: entries,
            gitErrorMessage: errorMessage
        )
        controller.onWindowWillClose = { [weak self] wc in
            self?.openWorktreeWindows.removeAll { $0 === wc }
        }
        openWorktreeWindows.append(controller)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func localizedMessage(for error: WorktreeServiceError) -> String {
        switch error {
        case .notARepository:
            return "이 폴더는 git 저장소가 아닙니다."
        case .gitFailed(let stderr, let status):
            return stderr.isEmpty ? "git 명령 실패 (코드 \(status))" : "git 오류 (코드 \(status)): \(stderr)"
        case .parseFailed(let detail):
            return "워크트리 정보를 파싱할 수 없습니다: \(detail)"
        }
    }

    func showSetupWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))

        let titleLabel = label("Goto", font: .boldSystemFont(ofSize: 22))
        let descriptionLabel = label(
            "Finder toolbar and context menu extension for opening the current Finder location in your selected terminal.",
            font: .systemFont(ofSize: 13)
        )
        descriptionLabel.maximumNumberOfLines = 3

        let terminalLabel = label("Default terminal", font: .systemFont(ofSize: 13, weight: .semibold))
        let terminalPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        terminalPopup.target = self
        terminalPopup.action = #selector(defaultTerminalDidChange(_:))
        terminalPopup.translatesAutoresizingMaskIntoConstraints = false
        configureTerminalPopup(terminalPopup)

        let terminalStatusLabel = label(terminalStatusText(), font: .systemFont(ofSize: 12))
        terminalStatusLabel.textColor = .secondaryLabelColor
        terminalStatusLabel.maximumNumberOfLines = 3

        let terminalStack = NSStackView(views: [terminalLabel, terminalPopup, terminalStatusLabel])
        terminalStack.orientation = .vertical
        terminalStack.alignment = .leading
        terminalStack.spacing = 6
        terminalStack.translatesAutoresizingMaskIntoConstraints = false

        let existingBehaviorLabel = label("When terminal is already running", font: .systemFont(ofSize: 13, weight: .semibold))
        let existingBehaviorPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        existingBehaviorPopup.target = self
        existingBehaviorPopup.action = #selector(existingBehaviorDidChange(_:))
        existingBehaviorPopup.translatesAutoresizingMaskIntoConstraints = false
        configureExistingBehaviorPopup(existingBehaviorPopup)

        let existingBehaviorStack = NSStackView(views: [existingBehaviorLabel, existingBehaviorPopup])
        existingBehaviorStack.orientation = .vertical
        existingBehaviorStack.alignment = .leading
        existingBehaviorStack.spacing = 6
        existingBehaviorStack.translatesAutoresizingMaskIntoConstraints = false

        let cliSortLabel = label("CLI project list sorting", font: .systemFont(ofSize: 13, weight: .semibold))
        let parentSortLabel = label("상위 폴더 정렬", font: .systemFont(ofSize: 12))
        let parentSortPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        parentSortPopup.target = self
        parentSortPopup.action = #selector(parentSortDidChange(_:))
        parentSortPopup.translatesAutoresizingMaskIntoConstraints = false
        configureParentSortPopup(parentSortPopup)

        let projectSortLabel = label("프로젝트 정렬", font: .systemFont(ofSize: 12))
        let projectSortPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        projectSortPopup.target = self
        projectSortPopup.action = #selector(projectSortDidChange(_:))
        projectSortPopup.translatesAutoresizingMaskIntoConstraints = false
        configureProjectSortPopup(projectSortPopup)

        let parentSortRow = NSStackView(views: [parentSortLabel, parentSortPopup])
        parentSortRow.orientation = .horizontal
        parentSortRow.alignment = .centerY
        parentSortRow.spacing = 12
        parentSortRow.translatesAutoresizingMaskIntoConstraints = false

        let projectSortRow = NSStackView(views: [projectSortLabel, projectSortPopup])
        projectSortRow.orientation = .horizontal
        projectSortRow.alignment = .centerY
        projectSortRow.spacing = 12
        projectSortRow.translatesAutoresizingMaskIntoConstraints = false

        let cliSortStack = NSStackView(views: [cliSortLabel, parentSortRow, projectSortRow])
        cliSortStack.orientation = .vertical
        cliSortStack.alignment = .leading
        cliSortStack.spacing = 6
        cliSortStack.translatesAutoresizingMaskIntoConstraints = false

        let statusLabel = label(extensionStatusText(), font: .systemFont(ofSize: 13))
        let launcherLabel = label(
            "For one-click Finder toolbar use, drag Goto Launcher.app from Applications into the Finder toolbar.",
            font: .systemFont(ofSize: 12)
        )
        launcherLabel.textColor = .secondaryLabelColor
        launcherLabel.maximumNumberOfLines = 2

        let settingsButton = NSButton(title: "Open Extension Settings", target: self, action: #selector(openExtensionSettings))
        settingsButton.bezelStyle = .rounded

        let menuBarCheckbox = NSButton(checkboxWithTitle: "메뉴바에서 빠르게 열기", target: self, action: #selector(menuBarToggleChanged(_:)))
        menuBarCheckbox.state = GotoSettings.isMenuBarEnabled() ? .on : .off
        menuBarCheckbox.translatesAutoresizingMaskIntoConstraints = false

        let menuBarProjectGroupingCheckbox = NSButton(checkboxWithTitle: "프로젝트 그룹화", target: self, action: #selector(menuBarProjectGroupingToggleChanged(_:)))
        menuBarProjectGroupingCheckbox.state = GotoSettings.isMenuBarProjectGroupingEnabled() ? .on : .off
        menuBarProjectGroupingCheckbox.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [titleLabel, descriptionLabel, terminalStack, existingBehaviorStack, cliSortStack, menuBarCheckbox, menuBarProjectGroupingCheckbox, statusLabel, launcherLabel, settingsButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            terminalPopup.widthAnchor.constraint(equalToConstant: 220),
            existingBehaviorPopup.widthAnchor.constraint(equalToConstant: 220),
            parentSortLabel.widthAnchor.constraint(equalToConstant: 90),
            projectSortLabel.widthAnchor.constraint(equalToConstant: 90),
            parentSortPopup.widthAnchor.constraint(equalToConstant: 180),
            projectSortPopup.widthAnchor.constraint(equalToConstant: 180)
        ])

        let window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Goto"
        window.contentView = contentView
        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        self.terminalStatusLabel = terminalStatusLabel
    }

    @objc private func menuBarToggleChanged(_ sender: NSButton) {
        GotoSettings.setMenuBarEnabled(sender.state == .on)
        menuBarController?.update()
    }

    @objc private func menuBarProjectGroupingToggleChanged(_ sender: NSButton) {
        GotoSettings.setMenuBarProjectGroupingEnabled(sender.state == .on)
        menuBarController?.update()
    }

    @objc private func openExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    @objc private func defaultTerminalDidChange(_ sender: NSPopUpButton) {
        guard let preferenceValue = sender.selectedItem?.representedObject as? String,
              let preference = TerminalPreference(rawValue: preferenceValue) else {
            return
        }

        GotoSettings.saveDefaultTerminalPreference(preference)
        terminalStatusLabel?.stringValue = terminalStatusText()
    }

    @objc private func existingBehaviorDidChange(_ sender: NSPopUpButton) {
        guard let behaviorValue = sender.selectedItem?.representedObject as? String,
              let behavior = ExistingTerminalBehavior(rawValue: behaviorValue) else {
            return
        }

        GotoSettings.saveExistingTerminalBehavior(behavior)
        terminalStatusLabel?.stringValue = terminalStatusText()
    }

    @objc private func parentSortDidChange(_ sender: NSPopUpButton) {
        guard let option = selectedSortOption(in: sender) else { return }
        var config = GotoSettings.cliConfig()
        config.parentSortField = option.field
        config.parentSortDirection = option.direction
        GotoSettings.saveCLIConfig(config)
        menuBarController?.update()
    }

    @objc private func projectSortDidChange(_ sender: NSPopUpButton) {
        guard let option = selectedSortOption(in: sender) else { return }
        var config = GotoSettings.cliConfig()
        config.projectSortField = option.field
        config.projectSortDirection = option.direction
        GotoSettings.saveCLIConfig(config)
        menuBarController?.update()
    }

    private func configureTerminalPopup(_ popup: NSPopUpButton) {
        popup.removeAllItems()

        for preference in GotoSettings.availableTerminalPreferences() {
            popup.addItem(withTitle: preference.settingsTitle)
            popup.lastItem?.representedObject = preference.rawValue
        }

        let selectedPreference = GotoSettings.defaultTerminalPreference()
        if let item = popup.itemArray.first(where: { ($0.representedObject as? String) == selectedPreference.rawValue }) {
            popup.select(item)
        }
    }

    private func configureExistingBehaviorPopup(_ popup: NSPopUpButton) {
        popup.removeAllItems()

        for behavior in ExistingTerminalBehavior.allCases {
            popup.addItem(withTitle: behavior.settingsTitle)
            popup.lastItem?.representedObject = behavior.rawValue
        }

        let selectedBehavior = GotoSettings.existingTerminalBehavior()
        if let item = popup.itemArray.first(where: { ($0.representedObject as? String) == selectedBehavior.rawValue }) {
            popup.select(item)
        }
    }

    private func configureParentSortPopup(_ popup: NSPopUpButton) {
        let config = GotoSettings.cliConfig()
        configureSortPopup(
            popup,
            selected: GotoSettings.sortOption(
                field: config.parentSortField,
                direction: config.parentSortDirection
            )
        )
    }

    private func configureProjectSortPopup(_ popup: NSPopUpButton) {
        let config = GotoSettings.cliConfig()
        configureSortPopup(
            popup,
            selected: GotoSettings.sortOption(
                field: config.projectSortField,
                direction: config.projectSortDirection
            )
        )
    }

    private func configureSortPopup(_ popup: NSPopUpButton, selected: GotoSortOption) {
        popup.removeAllItems()

        for option in GotoSortOption.allCases {
            popup.addItem(withTitle: option.title)
            popup.lastItem?.representedObject = option.identifier
        }

        if let item = popup.itemArray.first(where: { ($0.representedObject as? String) == selected.identifier }) {
            popup.select(item)
        }
    }

    private func selectedSortOption(in popup: NSPopUpButton) -> GotoSortOption? {
        guard let identifier = popup.selectedItem?.representedObject as? String else {
            return nil
        }

        return GotoSortOption(identifier: identifier)
    }

    private func terminalStatusText() -> String {
        let selectedPreference = GotoSettings.defaultTerminalPreference()
        let selectedBehavior = GotoSettings.existingTerminalBehavior()
        let accessibilityNote = " Terminal tabs require Accessibility permission; otherwise Goto opens a new window."

        if TerminalLauncher.isGhosttyAvailable() {
            var message = "\(selectedPreference.displayName) will be used as the default Finder action."
            if selectedPreference == .terminal && selectedBehavior == .tab {
                message += accessibilityNote
            }

            return message
        }

        var message = "Ghostty is not installed, so Terminal will be used."
        if selectedBehavior == .tab {
            message += accessibilityNote
        }

        return message
    }

    private func extensionStatusText() -> String {
        if FIFinderSyncController.isExtensionEnabled {
            return "Finder extension is enabled."
        }

        return "Enable the Goto Finder Extension in System Settings, then add the toolbar item from Finder toolbar customization."
    }

    private func label(_ text: String, font: NSFont) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
}
