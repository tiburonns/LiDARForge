import SwiftUI
import UIKit

struct ScannerView: View {
    let projectType: ProjectType
    private let existingProject: ScanProject?

    @EnvironmentObject private var appState: AppState

    @StateObject private var controller = LiDARSessionController()
    @StateObject private var rgbdRecorder = RGBDRecorder()
    @State private var stage: CaptureStage
    @State private var viewMode: SensorViewMode = .cameraPoints
    @State private var isRunning: Bool
    @State private var initialWorldMapData: Data?
    @State private var statusMessage: String?
    @State private var exportURL: URL?
    @State private var showHealthReport = false
    @State private var measurementMode = false

    @State private var projectID = UUID()
    @State private var projectCreatedAt = Date()

    init(
        projectType: ProjectType,
        initialStage: CaptureStage = .structure,
        existingProject: ScanProject? = nil
    ) {
        self.projectType = projectType
        self.existingProject = existingProject
        _stage = State(initialValue: initialStage)
        _isRunning = State(initialValue: existingProject == nil)
        _projectID = State(initialValue: existingProject?.id ?? UUID())
        _projectCreatedAt = State(
            initialValue: existingProject?.createdAt ?? Date()
        )
    }

    var body: some View {
        ZStack {
            ARScannerView(
                controller: controller,
                viewMode: viewMode,
                isRunning: isRunning,
                allowsTargetLock: projectType == .object,
                measurementMode: measurementMode,
                captureQuality: appState.captureQuality,
                rgbdRecorder: projectType == .video ? rgbdRecorder : nil,
                initialWorldMapData: initialWorldMapData
            )
            .ignoresSafeArea()

            if viewMode == .depth, let image = controller.depthPreview {
                sensorImage(image)
            } else if viewMode == .confidence, let image = controller.confidencePreview {
                sensorImage(image)
            }

            if measurementMode {
                measurementReticle
            } else if projectType == .object {
                targetReticle
            }

            VStack(spacing: 12) {
                header
                coachCard

                if projectType == .object, !measurementMode {
                    targetControls
                }

                if measurementMode {
                    measurementCard
                }

                if projectType == .video {
                    rgbdRecorderCard
                }

                Spacer()

                if projectType == .object, controller.targetLocked {
                    coverageHeatmap
                }

                metrics
                modePicker
                controls
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHealthReport) {
            NavigationStack {
                ScanHealthReportView(
                    projectType: projectType,
                    stage: stage,
                    controller: controller
                )
            }
        }
        .onAppear {
            controller.configure(for: projectType)
            controller.setStage(stage)
            if let saved = existingProject?.measurements {
                controller.restoreMeasurements(saved)
            }
        }
        .onChange(of: stage) { _, newStage in
            controller.setStage(newStage)
        }
        .onChange(of: controller.worldMapData) { _, data in
            guard let data else { return }

            Task {
                _ = try? await ProjectStore.shared.saveWorldMap(
                    data,
                    projectID: projectID
                )
            }
        }
        .task {
            guard let existingProject else { return }

            initialWorldMapData = try? await ProjectStore.shared.loadWorldMap(
                projectID: existingProject.id
            )
            isRunning = true
        }
        .onDisappear {
            isRunning = false
            if rgbdRecorder.isRecording {
                rgbdRecorder.stop()
            }
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

    private var targetReticle: some View {
        VStack {
            Spacer()

            ZStack {
                Circle()
                    .stroke(
                        controller.targetLocked ? Color.green : Color.white,
                        lineWidth: 2
                    )
                    .frame(width: 54, height: 54)

                Circle()
                    .fill(
                        controller.targetLocked ? Color.green : Color.white
                    )
                    .frame(width: 5, height: 5)
            }
            .shadow(radius: 2)

            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var measurementReticle: some View {
        VStack {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 54, height: 54)

                Image(systemName: "plus")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
            }
            .shadow(radius: 2)

            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var measurementCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    controller.measurementDraftPointCount == 0
                        ? "measure.tapFirst"
                        : "measure.tapSecond",
                    systemImage: "ruler"
                )
                .font(.caption.bold())

                Spacer()

                if !controller.measurements.isEmpty {
                    Button("measure.clear") {
                        controller.clearMeasurements()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }

            if let latest = controller.measurements.first {
                HStack {
                    Text("measure.latest")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(
                        latest.distanceMeters.formatted(
                            .number.precision(.fractionLength(3))
                        ) + " m"
                    )
                    .font(.headline.monospacedDigit())
                }
            }

            if controller.measurements.count > 1 {
                Text(
                    String(
                        format: String(localized: "measure.count"),
                        controller.measurements.count
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var rgbdRecorderCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(
                    rgbdRecorder.isRecording
                        ? "rgbd.recording"
                        : "rgbd.title",
                    systemImage: rgbdRecorder.isRecording
                        ? "record.circle.fill"
                        : "video.badge.waveform"
                )
                .font(.caption.bold())

                Spacer()

                if rgbdRecorder.isRecording {
                    Text("\(rgbdRecorder.frameCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Text(
                rgbdRecorder.isRecording
                    ? "rgbd.recording.subtitle"
                    : "rgbd.subtitle"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            HStack {
                if rgbdRecorder.isRecording {
                    Button {
                        rgbdRecorder.stop()
                    } label: {
                        Label("rgbd.stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                } else if rgbdRecorder.isFinalizing {
                    ProgressView()
                    Text("rgbd.finalizing")
                        .font(.caption)
                } else {
                    Button {
                        rgbdRecorder.start(projectID: projectID)
                    } label: {
                        Label("rgbd.start", systemImage: "record.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()

                if let packageURL = rgbdRecorder.packageURL,
                   !rgbdRecorder.isFinalizing {
                    ShareLink(item: packageURL) {
                        Label("rgbd.share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let error = rgbdRecorder.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var targetControls: some View {
        VStack(spacing: 8) {
            HStack {
                Label(
                    controller.targetLocked
                        ? "target.locked"
                        : "target.tapToLock",
                    systemImage: controller.targetLocked
                        ? "scope"
                        : "hand.tap"
                )
                .font(.caption.bold())

                Spacer()

                if controller.targetLocked {
                    Button("target.clear") {
                        controller.clearTarget()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }

            if controller.targetLocked {
                HStack(spacing: 10) {
                    Text("target.radius")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Slider(
                        value: Binding(
                            get: { controller.targetRadiusMeters },
                            set: { controller.setTargetRadius($0) }
                        ),
                        in: 0.20...3.00,
                        step: 0.05
                    )

                    Text(
                        controller.targetRadiusMeters.formatted(
                            .number.precision(.fractionLength(2))
                        ) + " m"
                    )
                    .font(.caption2.monospacedDigit())
                    .frame(width: 52, alignment: .trailing)
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var coverageHeatmap: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("coverage.map", systemImage: "square.grid.3x3.fill")
                    .font(.caption.bold())

                Spacer()

                Text("coverage.directional")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        ForEach(0..<8, id: \.self) { column in
                            let value = controller.coverageSectors[row * 8 + column]
                            RoundedRectangle(cornerRadius: 3)
                                .fill(coverageColor(value))
                                .frame(height: 12)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                legend(color: .red, key: "coverage.missing")
                legend(color: .yellow, key: "coverage.partial")
                legend(color: .green, key: "coverage.good")
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func coverageColor(_ value: Double) -> Color {
        if value >= 0.66 { return .green }
        if value >= 0.25 { return .yellow }
        return .red
    }

    private func legend(color: Color, key: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(key)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
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
                    if projectType == .object, next == .appearance {
                        NavigationLink {
                            ObjectCaptureProjectView(projectID: projectID)
                        } label: {
                            Label(
                                "objectCapture.continueAppearance",
                                systemImage: "camera.macro"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                persist(
                                    stage: stage,
                                    showConfirmation: false
                                )
                            }
                        )
                    } else {
                        Button {
                            persist(stage: stage, showConfirmation: false)
                            stage = next
                            controller.reset(clearPointCloud: false)
                        } label: {
                            Label("scan.nextPass", systemImage: "arrow.right")
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button {
                        persist(
                            stage: stage,
                            showConfirmation: true,
                            presentHealthReport: true
                        )
                    } label: {
                        Label("scan.save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack {
                Button {
                    measurementMode.toggle()
                    if !measurementMode {
                        controller.cancelMeasurementDraft()
                    }
                } label: {
                    Label(
                        measurementMode ? "measure.done" : "measure.title",
                        systemImage: "ruler"
                    )
                }
                .buttonStyle(.bordered)

                Button {
                    showHealthReport = true
                } label: {
                    Label("health.title", systemImage: "waveform.path.ecg")
                }
                .buttonStyle(.bordered)

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

    private func persist(
        stage: CaptureStage,
        showConfirmation: Bool,
        presentHealthReport: Bool = false
    ) {
        let project = ScanProject(
            id: projectID,
            createdAt: projectCreatedAt,
            updatedAt: Date(),
            name: projectType.rawValue.capitalized,
            type: projectType,
            stage: stage,
            metrics: controller.snapshot,
            measurements: controller.measurements
        )

        controller.requestWorldMapSave()

        Task {
            do {
                _ = try await ProjectStore.shared.save(project)

                let pointCloud = await MainActor.run {
                    controller.bestPointCloudSnapshot()
                }

                if !pointCloud.points.isEmpty {
                    _ = try? await ProjectStore.shared.savePointCloud(
                        pointCloud,
                        projectID: projectID
                    )
                }

                await MainActor.run {
                    if showConfirmation {
                        statusMessage = String(localized: "project.saved")
                    }
                    if presentHealthReport {
                        showHealthReport = true
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


private struct ScanHealthReportView: View {
    let projectType: ProjectType
    let stage: CaptureStage
    @ObservedObject var controller: LiDARSessionController

    @Environment(\.dismiss) private var dismiss

    private var densityScore: Double {
        min(Double(controller.densePointCount) / 60_000.0, 1)
    }

    private var trackingScore: Double {
        controller.trackingDescription == "Normal" ? 1 : 0.35
    }

    private var overallScore: Double {
        let confidence = controller.confidence ?? 0.5
        return min(
            1,
            controller.coverage * 0.35 +
            controller.depthValidRatio * 0.20 +
            confidence * 0.20 +
            densityScore * 0.15 +
            trackingScore * 0.10
        )
    }

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("health.overall")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(
                            overallScore.formatted(
                                .percent.precision(.fractionLength(0))
                            )
                        )
                        .font(.largeTitle.bold())
                        .monospacedDigit()
                    }

                    Spacer()

                    Image(systemName: healthSymbol)
                        .font(.system(size: 34))
                }
            }

            Section("health.capture") {
                scoreRow("metric.coverage", controller.coverage)
                scoreRow("health.depthValidity", controller.depthValidRatio)
                scoreRow("metric.confidence", controller.confidence ?? 0)
                scoreRow("health.pointDensity", densityScore)

                LabeledContent("metric.tracking") {
                    Text(controller.trackingDescription)
                }

                LabeledContent("health.densePoints") {
                    Text("\(controller.densePointCount)")
                        .monospacedDigit()
                }
            }

            if projectType == .object {
                Section("target.title") {
                    LabeledContent("target.status") {
                        Text(
                            controller.targetLocked
                                ? String(localized: "target.locked")
                                : String(localized: "target.notLocked")
                        )
                    }

                    if controller.targetLocked {
                        LabeledContent("target.radius") {
                            Text(
                                controller.targetRadiusMeters.formatted(
                                    .number.precision(.fractionLength(2))
                                ) + " m"
                            )
                        }
                    }
                }
            }

            Section("health.recommendation") {
                Label(
                    LocalizedStringKey(recommendationKey),
                    systemImage: recommendationSymbol
                )
            }
        }
        .navigationTitle("health.title")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("common.ok") {
                    dismiss()
                }
            }
        }
    }

    private func scoreRow(
        _ key: LocalizedStringKey,
        _ value: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(key)
                Spacer()
                Text(
                    value.formatted(
                        .percent.precision(.fractionLength(0))
                    )
                )
                .monospacedDigit()
            }
            ProgressView(value: min(max(value, 0), 1))
        }
    }

    private var healthSymbol: String {
        if overallScore >= 0.80 { return "checkmark.seal.fill" }
        if overallScore >= 0.55 { return "exclamationmark.triangle.fill" }
        return "arrow.triangle.2.circlepath"
    }

    private var recommendationKey: String {
        if controller.trackingDescription != "Normal" {
            return "health.recommend.tracking"
        }
        if controller.depthValidRatio < 0.35 {
            return "health.recommend.depth"
        }
        if projectType == .object, !controller.targetLocked {
            return "health.recommend.target"
        }
        if controller.coverage < projectType.captureProfile.targetCoverage {
            return "health.recommend.coverage"
        }
        if densityScore < 0.40 {
            return "health.recommend.density"
        }
        return "health.recommend.ready"
    }

    private var recommendationSymbol: String {
        overallScore >= 0.80 ? "checkmark.circle" : "lightbulb"
    }
}
