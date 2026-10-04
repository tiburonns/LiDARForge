import SwiftUI

struct ToolsView: View {
    @EnvironmentObject private var appState: AppState

    private let columns = [
        GridItem(.adaptive(minimum: 155), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("tools.hero.title")
                        .font(.title2.bold())

                    Text("tools.hero.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                let enabled = appState.sensorTools.filter(appState.isEnabled)

                if enabled.isEmpty {
                    ContentUnavailableView(
                        "customize.noSensorTools",
                        systemImage: "slider.horizontal.3",
                        description: Text("customize.noSensorTools.subtitle")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(enabled) { tool in
                            NavigationLink {
                                destination(for: tool)
                            } label: {
                                toolCard(tool)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
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

    private func toolCard(_ tool: WorkspaceTool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: tool.symbol)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(LocalizedStringKey(tool.titleKey))
                .font(.headline)

            Text(LocalizedStringKey(tool.subtitleKey))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    @ViewBuilder
    private func destination(for tool: WorkspaceTool) -> some View {
        switch tool {
        case .nightVision:
            SensorToolView(
                titleKey: tool.titleKey,
                tool: tool,
                mode: .depth,
                nightVision: true
            )

        case .depthView:
            SensorToolView(
                titleKey: tool.titleKey,
                tool: tool,
                mode: .depth
            )

        case .confidenceView:
            SensorToolView(
                titleKey: tool.titleKey,
                tool: tool,
                mode: .confidence
            )

        case .featurePoints:
            SensorToolView(
                titleKey: tool.titleKey,
                tool: tool,
                mode: .cameraPoints
            )

        case .meshView:
            SensorToolView(
                titleKey: tool.titleKey,
                tool: tool,
                mode: .mesh
            )

        case .rawInspector:
            SensorToolView(
                titleKey: tool.titleKey,
                tool: tool,
                mode: .raw
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
