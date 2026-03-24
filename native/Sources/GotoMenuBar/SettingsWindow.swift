import ServiceManagement
import SwiftUI

import GotoNativeCore

struct SettingsWindow: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @AppStorage(TerminalPreference.userDefaultsKey) private var terminalRaw = "auto"
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    @State private var installedTerminals: [TerminalApp] = []
    @State private var autoLabel = "Auto"
    @State private var finderEnabled: Bool = true
    @State private var finderClickMode: FinderClickMode = .directPlusList

    private let sharedSettings = SharedSettings()

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

            Section("Finder") {
                Toggle("Finder toolbar integration", isOn: $finderEnabled)
                    .onChange(of: finderEnabled) { _ in
                        saveFinderPreference()
                    }

                Picker("Click behavior", selection: $finderClickMode) {
                    ForEach(FinderClickMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .disabled(!finderEnabled)
                .onChange(of: finderClickMode) { _ in
                    saveFinderPreference()
                }
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section {
                Button("Quit goto") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 360)
        .onAppear {
            installedTerminals = TerminalApp.installedApps
            autoLabel = "Auto (\(TerminalAppDetector().detect().displayName))"
            syncLaunchAtLoginState()
            loadFinderPreference()
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

    private func loadFinderPreference() {
        let pref = sharedSettings.loadFinderPreference()
        finderEnabled = pref.enabled
        finderClickMode = pref.clickMode
    }

    private func saveFinderPreference() {
        let pref = FinderPreference(clickMode: finderClickMode, enabled: finderEnabled)
        try? sharedSettings.saveFinderPreference(pref)
    }
}
