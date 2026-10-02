import SwiftUI

struct ToolsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            let enabled = appState.sensorTools.filter(appState.isEnabled)

            if enabled.isEmpty {
                ContentUnavailableView(
                    "customize.noSensorTools",
                    systemImage: "slider.horizontal.3",
                    description: Text("customize.noSensorTools.subtitle")
                )
            } else {
                ForEach(enabled) { tool in
                    NavigationLink {
                        destination(for: tool)
                    } label: {
                        Label(
                            LocalizedStringKey(tool.titleKey),
                            systemImage: tool.symbol
                        )
                    }
                }
            }
        }
        .navigationTitle("home.sensorTools")
        .toolbar {
            NavigationLink {
                ToolCustomizationProxyView()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
        }
    }

    @ViewBuilder
    private func destination(for tool: WorkspaceTool) -> some View {
        switch tool {
        case .nightVision:
            SensorToolView(
                titleKey: tool.titleKey,
                initialMode: .depth,
                nightVision: true
            )

        case .depthView:
            SensorToolView(
                titleKey: tool.titleKey,
                initialMode: .depth,
                nightVision: false
            )

        case .confidenceView:
            SensorToolView(
                titleKey: tool.titleKey,
                initialMode: .confidence,
                nightVision: false
            )

        case .featurePoints:
            SensorToolView(
                titleKey: tool.titleKey,
                initialMode: .cameraPoints,
                nightVision: false
            )

        case .meshView:
            SensorToolView(
                titleKey: tool.titleKey,
                initialMode: .mesh,
                nightVision: false
            )

        case .rawInspector:
            SensorToolView(
                titleKey: tool.titleKey,
                initialMode: .raw,
                nightVision: false
            )

        default:
            EmptyView()
        }
    }
}

private struct ToolCustomizationProxyView: View {
    var body: some View {
        SettingsToolCustomizationLinkView()
    }
}

private struct SettingsToolCustomizationLinkView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section("customize.sensorTools") {
                ForEach(appState.sensorTools) { tool in
                    Toggle(
                        isOn: Binding(
                            get: { appState.isEnabled(tool) },
                            set: { appState.setEnabled($0, for: tool) }
                        )
                    ) {
                        Label(
                            LocalizedStringKey(tool.titleKey),
                            systemImage: tool.symbol
                        )
                    }
                }
                .onMove { source, destination in
                    appState.moveTools(
                        in: \WorkspaceTool.isSensorTool,
                        from: source,
                        to: destination
                    )
                }
            }
        }
        .navigationTitle("customize.sensorTools")
        .toolbar {
            EditButton()
        }
    }
}
