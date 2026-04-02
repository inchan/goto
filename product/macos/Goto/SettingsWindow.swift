import ServiceManagement
import SwiftUI

struct SettingsWindow: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @AppStorage(TerminalPreference.userDefaultsKey) private var terminalRaw = "auto"
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    @State private var installedTerminals: [TerminalApp] = []
    @State private var autoLabel = "Auto"

    var body: some View {
        Form {
            Section("Terminal") {
                Picker("Open projects in", selection: $terminalRaw) {
                    Text(autoLabel).tag("auto")
                    ForEach(installedTerminals) { app in
                        Text(app.displayName).tag(app.rawValue)
                    }
                }
                .onChange(of: terminalRaw) { _ in
                    TerminalPreference(rawValue: terminalRaw).save()
                    viewModel.reloadLauncher()
                }
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section("Shell Integration") {
                Text("Pkg installs expose goto-install-shell for shell cd integration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Quit goto") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 320)
        .onAppear {
            installedTerminals = TerminalApp.installedApps
            autoLabel = "Auto (\(TerminalAppDetector().detect().displayName))"
            syncLaunchAtLoginState()
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {}
    }

    private func syncLaunchAtLoginState() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
