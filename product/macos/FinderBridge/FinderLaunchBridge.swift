import AppKit
import Foundation

final class FinderLaunchBridge {
    static let shared = FinderLaunchBridge()

    private var started = false
    private let presenter = FinderErrorPresenter()
    private let selection = FinderSelection()
    private let store = RegistryStore()
    private let settings = SharedSettings()
    private var registryWatcher: RegistryWatcher?
    private var settingsWatcher: RegistryWatcher?
    private var observedDirectoryPaths: [String] = []

    private init() {}

    func start() {
        guard !started else {
            return
        }

        started = true
        debug("bridge start")

        broadcastProjectList()
        broadcastFinderPreference()
        startRegistryWatcher()
        startSettingsWatcher()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleLaunchRequest(_:)),
            name: .gotoFinderLaunchRequested,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleObservedDirectoryBegan(_:)),
            name: .gotoFinderObservedDirectoryBegan,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleExtensionReady(_:)),
            name: .gotoExtensionReady,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleLaunchProbe(_:)),
            name: .gotoFinderLaunchProbe,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleObservedDirectoryEnded(_:)),
            name: .gotoFinderObservedDirectoryEnded,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    func handle(url: URL) {
        debug("handle url=\(url.absoluteString)")

        guard let request = FinderLaunchURL.parse(url) else {
            debug("ignored unknown url=\(url.absoluteString)")
            return
        }

        handle(request: request)
    }

    @objc private func handleExtensionReady(_ notification: Notification) {
        debug("extension ready — re-broadcasting")
        broadcastProjectList()
        broadcastFinderPreference()
    }

    @objc private func handleLaunchRequest(_ notification: Notification) {
        debug("launch notification userInfo=\(String(describing: notification.userInfo))")
        guard let request = request(from: notification) else {
            debug("ignored launch notification with no parseable request")
            return
        }

        handle(request: request)
    }

    @objc private func handleLaunchProbe(_ notification: Notification) {
        debug("launch probe received userInfo=\(String(describing: notification.userInfo))")
    }

    private func handle(request: FinderLaunchRequest) {
        let pref = settings.loadFinderPreference()
        guard pref.enabled else {
            debug("finder disabled, ignoring request")
            return
        }

        debug("launch request request=\(request)")
        do {
            let url = try requestedDirectoryURL(from: request)
            debug("resolved request url=\(url.path)")
            let directory = try selection.resolveSelectedDirectory(
                from: [url]
            )
            let request = TerminalLaunchRequest(directory: directory, surface: .finder)
            try TerminalLauncher().launch(request)
            debug("launch success path=\(directory.path)")
        } catch let error as FinderSelectionError {
            debug("selection error=\(error)")
            present(presenter.present(selectionError: error))
        } catch let error as TerminalLaunchError {
            debug("launch error=\(error)")
            present(presenter.present(launchError: error))
        } catch let error as FinderLaunchBridgeError {
            debug("bridge error title=\(error.title) message=\(error.message)")
            present(UserFacingError(title: error.title, message: error.message))
        } catch {
            debug("unexpected error=\(error.localizedDescription)")
            present(UserFacingError(title: "goto Error", message: error.localizedDescription))
        }
    }

    private func request(from notification: Notification) -> FinderLaunchRequest? {
        if let mode = notification.userInfo?[FinderLaunchNotification.modeKey] as? String,
           mode == FinderLaunchNotification.currentFinderFolderMode {
            debug("parsed current finder folder request from notification")
            return .currentFinderFolder
        }

        if let path = notification.userInfo?[FinderLaunchNotification.pathKey] as? String,
           !path.isEmpty {
            debug("parsed path request from notification path=\(path)")
            return .path(path)
        }

        return nil
    }

    private func requestedDirectoryURL(from request: FinderLaunchRequest) throws -> URL {
        switch request {
        case .currentFinderFolder:
            debug("current finder folder mode with observed=\(observedDirectoryPaths)")
            return try currentFinderDirectoryURL()
        case let .path(path):
            return URL(fileURLWithPath: path, isDirectory: true)
        }
    }

    private func currentFinderDirectoryURL() throws -> URL {
        if let path = observedDirectoryPaths.last, !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        return try currentFinderDirectoryURLViaAutomation()
    }

    @objc private func handleObservedDirectoryBegan(_ notification: Notification) {
        guard
            let path = notification.userInfo?[FinderLaunchNotification.pathKey] as? String,
            !path.isEmpty
        else {
            return
        }

        observedDirectoryPaths.removeAll { $0 == path }
        observedDirectoryPaths.append(path)
        debug("observed begin path=\(path); observed=\(observedDirectoryPaths)")
    }

    @objc private func handleObservedDirectoryEnded(_ notification: Notification) {
        guard
            let path = notification.userInfo?[FinderLaunchNotification.pathKey] as? String,
            !path.isEmpty
        else {
            return
        }

        observedDirectoryPaths.removeAll { $0 == path }
        debug("observed end path=\(path); observed=\(observedDirectoryPaths)")
    }

    private func present(_ error: UserFacingError) {
        debug("present alert title=\(error.title) message=\(error.message)")
        let alert = NSAlert()
        alert.messageText = error.title
        alert.informativeText = error.message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static let logURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("goto-bridge.log")
    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    private func debug(_ message: String) {
        let line = "[\(Self.dateFormatter.string(from: Date()))] \(message)\n"
        let data = Data(line.utf8)

        if let handle = try? FileHandle(forWritingTo: Self.logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: Self.logURL)
        }
    }

    private func currentFinderDirectoryURLViaAutomation() throws -> URL {
        NSApplication.shared.activate(ignoringOtherApps: true)

        let script = """
        tell application "Finder"
            if (count of Finder windows) is 0 then
                return POSIX path of (desktop as alias)
            end if

            return POSIX path of (target of front Finder window as alias)
        end tell
        """

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0, !stdout.isEmpty else {
            let message: String
            if stderr.contains("-1743") || stderr.localizedCaseInsensitiveContains("not authorized") {
                message = "Allow goto to control Finder in System Settings, then try again."
            } else if stderr.isEmpty {
                message = "goto could not read the current Finder folder."
            } else {
                message = stderr
            }

            throw FinderLaunchBridgeError(
                title: "Finder Folder Unavailable",
                message: message
            )
        }

        return URL(fileURLWithPath: stdout, isDirectory: true)
    }

    // MARK: - Broadcast to Finder Extension

    func broadcastProjectList() {
        let projects = (try? store.loadProjects()) ?? []
        let paths = projects.filter(\.exists).map(\.path)
        let encoded = FinderSyncBroadcast.encodeProjects(paths)
        debug("broadcast projects count=\(paths.count)")
        DistributedNotificationCenter.default().postNotificationName(
            .gotoProjectListUpdated,
            object: nil,
            userInfo: [FinderSyncBroadcast.projectsKey: encoded],
            options: [.deliverImmediately]
        )
    }

    func broadcastFinderPreference() {
        let pref = settings.loadFinderPreference()
        debug("broadcast pref clickMode=\(pref.clickMode.rawValue) enabled=\(pref.enabled)")
        DistributedNotificationCenter.default().postNotificationName(
            .gotoFinderPreferenceUpdated,
            object: nil,
            userInfo: [
                FinderSyncBroadcast.clickModeKey: pref.clickMode.rawValue,
                FinderSyncBroadcast.enabledKey: pref.enabled,
            ],
            options: [.deliverImmediately]
        )
    }

    private func startRegistryWatcher() {
        registryWatcher = RegistryWatcher(registryURL: store.registryURL) { [weak self] in
            self?.broadcastProjectList()
        }
        registryWatcher?.start()
    }

    private func startSettingsWatcher() {
        settingsWatcher = RegistryWatcher(registryURL: settings.settingsURL) { [weak self] in
            self?.broadcastFinderPreference()
        }
        settingsWatcher?.start()
    }
}

private struct FinderLaunchBridgeError: Error {
    let title: String
    let message: String
}
