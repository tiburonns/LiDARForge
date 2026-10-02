import SwiftUI
import UIKit

struct ScannerView: View {
    let projectType: ProjectType

    @StateObject private var controller = LiDARSessionController()
    @State private var stage: CaptureStage = .structure
    @State private var viewMode: SensorViewMode = .cameraPoints
    @State private var isRunning = true
    @State private var statusMessage: String?
    @State private var exportURL: URL?

    @State private var projectID = UUID()
    @State private var projectCreatedAt = Date()

    var body: some View {
        ZStack {
            ARScannerView(
                controller: controller,
                viewMode: viewMode,
                isRunning: isRunning
            )
            .ignoresSafeArea()

            if viewMode == .depth, let image = controller.depthPreview {
                sensorImage(image)
            } else if viewMode == .confidence, let image = controller.confidencePreview {
                sensorImage(image)
            }

            VStack(spacing: 12) {
                header
                coachCard
                Spacer()
                metrics
                modePicker
                controls
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            controller.configure(for: projectType)
        }
        .onDisappear {
            isRunning = false
        }
        .alert(
            "LiDARForge",
            isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )
        ) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(statusMessage ?? "")
        }
    }

    private func sensorImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .background(.black)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    LocalizedStringKey(projectType.titleKey),
                    systemImage: projectType.symbol
                )
                .font(.headline)

                Spacer()

                Text(LocalizedStringKey(stage.titleKey))
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }

            Text(LocalizedStringKey(stage.instructionKey))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: controller.coverage)
                .tint(controller.recommendedReady ? .green : .accentColor)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var coachCard: some View {
        HStack(spacing: 10) {
            Image(systemName: controller.captureGuidance.symbol)
                .font(.headline)

            VStack(alignment: .leading, spacing: 2) {
                Text("coach.title")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(LocalizedStringKey(controller.captureGuidance.titleKey))
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()

            if controller.recommendedReady {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            metric(
                title: "metric.coverage",
                value: controller.coverage.formatted(.percent.precision(.fractionLength(0)))
            )

            metric(
                title: "metric.confidence",
                value: controller.confidence?.formatted(.percent.precision(.fractionLength(0))) ?? "—"
            )

            metric(
                title: "metric.distance",
                value: controller.centerDistanceMeters.map {
                    $0.formatted(.number.precision(.fractionLength(2))) + " m"
                } ?? "—"
            )

            metric(
                title: "metric.speed",
                value: controller.motionSpeed.formatted(.number.precision(.fractionLength(2))) + " m/s"
            )
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func metric(title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(SensorViewMode.allCases) { mode in
                    Button {
                        viewMode = mode
                    } label: {
                        Label(
                            LocalizedStringKey(mode.titleKey),
                            systemImage: mode.symbol
                        )
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            viewMode == mode ? .regularMaterial : .ultraThinMaterial,
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    isRunning.toggle()
                } label: {
                    Label(
                        isRunning ? "scan.pause" : "scan.resume",
                        systemImage: isRunning ? "pause.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)

                if let next = stage.next {
                    Button {
                        persist(stage: stage, showConfirmation: false)
                        stage = next
                        controller.reset(clearPointCloud: false)
                    } label: {
                        Label("scan.nextPass", systemImage: "arrow.right")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        persist(stage: stage, showConfirmation: true)
                    } label: {
                        Label("scan.save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack {
                Button {
                    exportPointCloud()
                } label: {
                    Label("export.ply", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .buttonStyle(.bordered)
                .disabled(
                    controller.densePointCount == 0 &&
                    controller.accumulatedPointCount == 0
                )

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("export.share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func persist(stage: CaptureStage, showConfirmation: Bool) {
        let project = ScanProject(
            id: projectID,
            createdAt: projectCreatedAt,
            updatedAt: Date(),
            name: projectType.rawValue.capitalized,
            type: projectType,
            stage: stage,
            metrics: controller.snapshot
        )

        Task {
            do {
                _ = try await ProjectStore.shared.save(project)
                if showConfirmation {
                    await MainActor.run {
                        statusMessage = String(localized: "project.saved")
                    }
                }
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                }
            }
        }
    }

    private func exportPointCloud() {
        let snapshot = controller.bestPointCloudSnapshot()

        do {
            exportURL = try PointCloudExporter.exportPLY(
                snapshot: snapshot,
                projectID: projectID
            )

            statusMessage = snapshot.source == .sceneDepth
                ? String(localized: "export.readyDense")
                : String(localized: "export.readySparse")
        } catch {
            statusMessage = String(localized: "export.failed")
        }
    }
}
