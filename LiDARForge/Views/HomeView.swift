import ARKit
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var supportsLiDARDepth: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero

                    if !supportsLiDARDepth {
                        unsupportedBanner
                    }

                    quickCapture
                    workspaceGrid
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.10),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .center
                )
                .ignoresSafeArea()
            )
            .navigationTitle("LiDARForge")
            .navigationBarTitleDisplayMode(.inline)
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

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("home.hero.title")
                        .font(.largeTitle.bold())

                    Text("home.hero.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "viewfinder.circle.fill")
                    .font(.system(size: 52))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
            }

            HStack(spacing: 8) {
                Label {
                    Text(
                        LocalizedStringKey(
                            supportsLiDARDepth
                                ? "home.lidar.ready"
                                : "home.lidar.limited"
                        )
                    )
                } icon: {
                    Image(
                        systemName: supportsLiDARDepth
                            ? "sensor.tag.radiowaves.forward.fill"
                            : "exclamationmark.triangle.fill"
                    )
                }
                .font(.caption.bold())

                Spacer()

                Text("home.localFirst")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    private var unsupportedBanner: some View {
        Label {
            Text("lidar.unsupported")
                .font(.subheadline)
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    private var quickCapture: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "home.quickCapture",
                subtitle: "home.quickCapture.subtitle"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ProjectType.allCases) { type in
                        NavigationLink {
                            destination(for: type)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: type.symbol)
                                    .font(.title2)
                                    .symbolRenderingMode(.hierarchical)

                                Spacer(minLength: 4)

                                Text(LocalizedStringKey(type.titleKey))
                                    .font(.headline)

                                Text(LocalizedStringKey(type.engineKey))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 148, height: 112, alignment: .leading)
                            .padding()
                            .background(
                                .thinMaterial,
                                in: RoundedRectangle(cornerRadius: 20)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var workspaceGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "home.workspace",
                subtitle: "home.workspace.subtitle"
            )

            LazyVGrid(columns: columns, spacing: 12) {
                NavigationLink {
                    NewProjectView()
                } label: {
                    actionCard(
                        title: "home.newProject",
                        subtitle: "home.newProject.subtitle",
                        symbol: "plus.viewfinder"
                    )
                }

                NavigationLink {
                    ProjectsView()
                } label: {
                    actionCard(
                        title: "projects.title",
                        subtitle: "home.projects.subtitle",
                        symbol: "square.stack.3d.up.fill"
                    )
                }

                NavigationLink {
                    ToolsView()
                } label: {
                    actionCard(
                        title: "home.sensorTools",
                        subtitle: "home.tools.subtitle",
                        symbol: "sensor.fill"
                    )
                }

                NavigationLink {
                    SettingsView()
                } label: {
                    actionCard(
                        title: "settings.title",
                        subtitle: "home.settings.subtitle",
                        symbol: "slider.horizontal.3"
                    )
                }
            }
        }
    }

    private func sectionHeader(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.bold())
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func actionCard(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    @ViewBuilder
    private func destination(for type: ProjectType) -> some View {
        if type == .interior {
            RoomPlanProjectView(projectType: type)
        } else if type == .building {
            BuildingRoomPlanProjectView()
        } else {
            ScannerView(projectType: type)
        }
    }
}
