import SwiftUI

struct ProjectsView: View {
    @State private var projects: [ScanProject] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if projects.isEmpty {
                ContentUnavailableView(
                    "projects.empty.title",
                    systemImage: "cube.transparent",
                    description: Text("projects.empty.subtitle")
                )
            } else {
                List {
                    ForEach(projects) { project in
                        NavigationLink {
                            ProjectDetailView(project: project)
                        } label: {
                            ProjectRow(project: project)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("projects.title")
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
    }

    private func reload() async {
        let stored = await ProjectStore.shared.listProjects()
        await MainActor.run {
            projects = stored
            isLoading = false
        }
    }

    private func delete(at offsets: IndexSet) {
        let ids = offsets.map { projects[$0].id }
        projects.remove(atOffsets: offsets)

        Task {
            for id in ids {
                try? await ProjectStore.shared.deleteProject(id: id)
            }
        }
    }
}

private struct ProjectRow: View {
    let project: ScanProject

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(
                    LocalizedStringKey(project.type.titleKey),
                    systemImage: project.type.symbol
                )
                .font(.headline)

                Spacer()

                Text(
                    project.updatedAt,
                    format: .dateTime.month().day().hour().minute()
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack {
                Text(LocalizedStringKey(project.stage.titleKey))
                Spacer()
                Text(
                    project.metrics.coverage,
                    format: .percent.precision(.fractionLength(0))
                )
            }
            .font(.subheadline)

            ProgressView(value: project.metrics.coverage)

            HStack(spacing: 12) {
                if let confidence = project.metrics.confidence {
                    Label(
                        confidence.formatted(
                            .percent.precision(.fractionLength(0))
                        ),
                        systemImage: "checkmark.shield"
                    )
                }

                if let dense = project.metrics.densePointCount {
                    Label(
                        dense.formatted(),
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                }

                if let count = project.measurements?.count,
                   count > 0 {
                    Label("\(count)", systemImage: "ruler")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct ProjectDetailView: View {
    let project: ScanProject

    @State private var pointCloudURL: URL?
    @State private var packageURL: URL?
    @State private var isBuildingPackage = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        LocalizedStringKey(project.type.titleKey),
                        systemImage: project.type.symbol
                    )
                    .font(.title2.bold())

                    Text(project.updatedAt, format: .dateTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    WorkflowProgressView(currentStage: project.stage)
                }
                .padding(.vertical, 4)
            }

            Section("projects.metrics") {
                metricRow(
                    "metric.coverage",
                    project.metrics.coverage.formatted(
                        .percent.precision(.fractionLength(0))
                    )
                )

                if let confidence = project.metrics.confidence {
                    metricRow(
                        "metric.confidence",
                        confidence.formatted(
                            .percent.precision(.fractionLength(0))
                        )
                    )
                }

                if let valid = project.metrics.depthValidRatio {
                    metricRow(
                        "health.depthValidity",
                        valid.formatted(
                            .percent.precision(.fractionLength(0))
                        )
                    )
                }

                if let dense = project.metrics.densePointCount {
                    metricRow("health.densePoints", dense.formatted())
                }

                metricRow(
                    "metric.tracking",
                    project.metrics.trackingDescription
                )
            }

            if let measurements = project.measurements,
               !measurements.isEmpty {
                Section("measure.title") {
                    ForEach(measurements) { measurement in
                        HStack {
                            Image(systemName: "ruler")
                                .foregroundStyle(.secondary)

                            Text(
                                measurement.createdAt,
                                format: .dateTime.hour().minute()
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Spacer()

                            Text(
                                measurement.distanceMeters.formatted(
                                    .number.precision(.fractionLength(3))
                                ) + " m"
                            )
                            .monospacedDigit()
                        }
                    }
                }
            }

            Section("projects.continue") {
                continuationDestination
            }

            Section("projects.exports") {
                if let pointCloudURL {
                    ShareLink(item: pointCloudURL) {
                        Label(
                            "projects.sharePointCloud",
                            systemImage: "point.3.connected.trianglepath.dotted"
                        )
                    }
                } else {
                    Label(
                        "projects.noPointCloud",
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                    .foregroundStyle(.secondary)
                }

                if let packageURL {
                    ShareLink(item: packageURL) {
                        Label(
                            "projects.sharePackage",
                            systemImage: "shippingbox"
                        )
                    }
                } else {
                    Button {
                        buildPackage()
                    } label: {
                        if isBuildingPackage {
                            HStack {
                                ProgressView()
                                Text("projects.buildingPackage")
                            }
                        } else {
                            Label(
                                "projects.buildPackage",
                                systemImage: "shippingbox"
                            )
                        }
                    }
                    .disabled(isBuildingPackage)
                }
            }
        }
        .navigationTitle("projects.detail")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            pointCloudURL = try? await ProjectStore.shared.pointCloudURL(
                projectID: project.id
            )
        }
        .alert(
            "LiDARForge",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var continuationDestination: some View {
        if project.type == .object,
           project.stage.next == .appearance {
            NavigationLink {
                ObjectCaptureProjectView(projectID: project.id)
            } label: {
                Label(
                    "objectCapture.continueAppearance",
                    systemImage: "camera.macro"
                )
            }
        } else {
            let next = project.stage.next ?? project.stage

            NavigationLink {
                ScannerView(
                    projectType: project.type,
                    initialStage: next,
                    existingProject: project
                )
            } label: {
                Label(
                    project.stage.next == nil
                        ? "projects.reopen"
                        : "projects.continueCapture",
                    systemImage: project.stage.next == nil
                        ? "arrow.clockwise"
                        : "play.circle"
                )
            }
        }
    }

    private func metricRow(
        _ key: LocalizedStringKey,
        _ value: String
    ) -> some View {
        LabeledContent(key) {
            Text(value)
                .monospacedDigit()
        }
    }

    private func buildPackage() {
        isBuildingPackage = true

        Task {
            do {
                let url = try await ProjectStore.shared.buildSharePackage(
                    projectID: project.id
                )

                await MainActor.run {
                    packageURL = url
                    isBuildingPackage = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isBuildingPackage = false
                }
            }
        }
    }
}

private struct WorkflowProgressView: View {
    let currentStage: CaptureStage

    var body: some View {
        HStack(spacing: 6) {
            ForEach(CaptureStage.allCases) { stage in
                HStack(spacing: 4) {
                    Image(
                        systemName: stageIndex(stage) <= stageIndex(currentStage)
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                    Text(LocalizedStringKey(stage.titleKey))
                }
                .font(.caption)
                .foregroundStyle(
                    stageIndex(stage) <= stageIndex(currentStage)
                        ? .primary
                        : .secondary
                )

                if stage != .appearance {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func stageIndex(_ stage: CaptureStage) -> Int {
        CaptureStage.allCases.firstIndex(of: stage) ?? 0
    }
}
