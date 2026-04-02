import SwiftUI

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var projects: [ProjectEntry] = []
    @Published private(set) var statusMessage: String?

    private let store: any ProjectListing
    private var launcher: any TerminalLaunching
    private var watcher: RegistryWatcher?

    init(
        store: any ProjectListing = RegistryStore(),
        launcher: any TerminalLaunching = TerminalLauncher()
    ) {
        self.store = store
        self.launcher = launcher
        reload()
        startWatching()
    }

    func reloadLauncher() {
        launcher = TerminalLauncher()
    }

    func startWatching() {
        guard watcher == nil, let registryStore = store as? RegistryStore else { return }
        watcher = RegistryWatcher(registryURL: registryStore.registryURL) { [weak self] in
            Task { @MainActor [weak self] in
                self?.reload()
            }
        }
        watcher?.start()
    }

    func reload() {
        do {
            projects = try store.loadProjects()
            statusMessage = reloadStatusMessage(for: projects)
        } catch {
            projects = []
            statusMessage = "Could not read ~/.goto: \(error.localizedDescription)"
        }
    }

    func open(_ project: ProjectEntry) {
        guard project.exists, RegistryStore.directoryExists(at: project.path) else {
            statusMessage = "This project path no longer exists."
            return
        }

        do {
            let request = TerminalLaunchRequest(
                directory: ValidatedDirectory(path: project.path, name: project.name)
            )
            try launcher.launch(request)
            statusMessage = nil
        } catch let error as TerminalLaunchError {
            let presenter = TerminalErrorPresenter()
            statusMessage = presenter.present(launchError: error).message
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func reloadStatusMessage(for projects: [ProjectEntry]) -> String? {
        if projects.isEmpty {
            return "Save a project with goto -a first."
        }

        let missingCount = projects.filter { !$0.exists }.count
        if missingCount == 0 {
            return nil
        }

        if missingCount == 1 {
            return "1 saved project is missing. Remove it or refresh the registry."
        }

        return "\(missingCount) saved projects are missing. Remove them or refresh the registry."
    }
}
