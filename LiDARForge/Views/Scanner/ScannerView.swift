import SwiftUI
import UIKit

struct ScannerView: View {
    let projectType: ProjectType

    @StateObject private var controller = LiDARSessionController()
    @State private var stage: CaptureStage = .structure
    @State private var viewMode: SensorViewMode = .cameraPoints
    @State private var isRunning = true
    @State private var saveMessage: String?

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
                Spacer()
                metrics
                modePicker
                controls
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            isRunning = false
        }
        .alert(
            "project.saved",
            isPresented: Binding(
                get: { saveMessage != nil },
                set: { if !$0 { saveMessage = nil } }
            )
        ) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(saveMessage ?? "")
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
                .tint(controller.coverage > 0.75 ? .green : .accentColor)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var metrics: some View {
        HStack(spacing: 14) {
            metric(
                title: "metric.coverage",
                value: controller.coverage.formatted(.percent.precision(.fractionLength(0)))
            )

            metric(
                title: "metric.confidence",
                value: controller.confidence?.formatted(.percent.precision(.fractionLength(0))) ?? "—"
            )

            metric(
                title: "metric.mesh",
                value: "\(controller.meshAnchorCount)"
            )

            metric(
                title: "metric.points",
                value: "\(controller.featurePointCount)"
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
                    stage = next
                    controller.reset()
                } label: {
                    Label("scan.nextPass", systemImage: "arrow.right")
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    saveSnapshot()
                } label: {
                    Label("scan.save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func saveSnapshot() {
        let project = ScanProject(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            name: projectType.rawValue.capitalized,
            type: projectType,
            stage: stage,
            metrics: controller.snapshot
        )

        Task {
            do {
                let url = try await ProjectStore.shared.save(project)
                await MainActor.run {
                    saveMessage = url.deletingLastPathComponent().lastPathComponent
                }
            } catch {
                await MainActor.run {
                    saveMessage = error.localizedDescription
                }
            }
        }
    }
}
