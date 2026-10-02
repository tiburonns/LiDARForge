import ARKit
import SwiftUI

struct HomeView: View {
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
    }
}
