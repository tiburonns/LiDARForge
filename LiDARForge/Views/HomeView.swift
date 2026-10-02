import ARKit
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    private var supportsLiDARDepth: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    var body: some View {
        NavigationStack {
            List {
                if !supportsLiDARDepth {
                    Section {
                        Label {
                            Text("lidar.unsupported")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                    }
                }

                Section("home.capture") {
                    NavigationLink {
                        NewProjectView()
                    } label: {
                        Label("home.newProject", systemImage: "viewfinder")
                    }

                    NavigationLink {
                        ProjectsView()
                    } label: {
                        Label("projects.title", systemImage: "square.stack.3d.up")
                    }
                }

                Section("home.tools") {
                    NavigationLink {
                        ToolsView()
                    } label: {
                        Label("home.sensorTools", systemImage: "sensor")
                    }
                }

                Section("home.settings") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("settings.title", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("LiDARForge")
        }
        .alert(
            "LiDARForge",
            isPresented: Binding(
                get: { appState.importMessage != nil },
                set: { if !$0 { appState.importMessage = nil } }
            )
        ) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(appState.importMessage ?? "")
        }
    }
}
