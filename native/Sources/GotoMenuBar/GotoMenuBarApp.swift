import SwiftUI

import GotoNativeCore

@main
struct GotoMenuBarApp: App {
    @StateObject private var viewModel = MenuBarViewModel()

    var body: some Scene {
        MenuBarExtra("goto", systemImage: "folder.circle") {
            MenuBarContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 360)
        }

        Window("goto Settings", id: "settings") {
            SettingsWindow(viewModel: viewModel)
        }
        .windowResizability(.contentSize)
    }
}

private struct MenuBarContentView: View {
    @EnvironmentObject var viewModel: MenuBarViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let status = viewModel.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Projects")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.projects.isEmpty {
                Text("No saved projects yet.")
                    .font(.body)
            } else {
                ForEach(viewModel.projects, id: \.path) { project in
                    Button {
                        viewModel.open(project)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(project.name)
                                Spacer(minLength: 12)

                                if !project.exists {
                                    Text("Missing")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }

                            Text(project.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .disabled(!project.exists)
                }
            }

            Divider()

            Button("Settings") {
                openWindow(id: "settings")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.borderless)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
    }
}
