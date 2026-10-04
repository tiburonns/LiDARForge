import SwiftUI
import UIKit

struct ScannerView: View {
    let projectType: ProjectType
    private let existingProject: ScanProject?

    @EnvironmentObject private var appState: AppState

    @StateObject private var controller = LiDARSessionController()
    @StateObject private var rgbdRecorder = RGBDRecorder()
    @StateObject private var sourceRecorder = RGBDRecorder()

    @State private var stage: CaptureStage
    @State private var viewMode: SensorViewMode = .camera
    @State private var isRunning: Bool
    @State private var initialWorldMapData: Data?

    @State private var showDetails = false
    @State private var showOptions = false
    @State private var measurementMode = false
    @State private var targetSelectionMode = false
    @State private var showSurfaceHeatmap = false

    @State private var statusMessage: String?
    @State private var exportURL: URL?

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
                allowsTargetLock:
                    projectType == .object &&
                    targetSelectionMode,
                measurementMode: measurementMode,
                captureQuality: appState.captureQuality,
                rgbdRecorder: projectType == .video
                    ? rgbdRecorder
                    : (
                        appState.isEnabled(.sourceArchive)
                            ? sourceRecorder
                            : nil
                    ),
                initialWorldMapData: initialWorldMapData,
                showSurfaceHeatmap:
                    appState.isEnabled(.coverageHeatmap) &&
                    showSurfaceHeatmap,
                captureWorkspace: true
            )
            .ignoresSafeArea()

            sensorPreview

            if measurementMode || targetSelectionMode {
                interactionReticle
            }

            VStack(spacing: 12) {
                compactProgressPanel

                Spacer()

                optionsButton
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showOptions) {
            optionsSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            controller.configure(for: projectType)
            controller.setStage(stage)
            showSurfaceHeatmap = false

            if let saved = existingProject?.measurements {
                controller.restoreMeasurements(saved)
            }

            if let savedCoverage = existingProject?.surfaceCoverage {
                controller.restoreSurfaceCoverage(savedCoverage)
            }

            if let savedTarget = existingProject?.target {
                controller.restoreTarget(savedTarget)
            }

            startSourceArchiveIfNeeded()
        }
        .onChange(of: stage) { _, newStage in
            controller.setStage(newStage)
        }
        .onChange(of: controller.targetLocked) { _, locked in
            if locked {
                targetSelectionMode = false
            }
        }
        .onChange(of: appState.enabledTools) { _, _ in
            if appState.isEnabled(.sourceArchive) {
                startSourceArchiveIfNeeded()
            } else if sourceRecorder.isRecording {
                sourceRecorder.stop()
            }

            if !appState.isEnabled(.coverageHeatmap) {
                showSurfaceHeatmap = false
            }

            if !availableViewModes.contains(viewMode) {
                viewMode = .camera
            }
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

            if sourceRecorder.isRecording {
                sourceRecorder.stop()
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

    @ViewBuilder
    private var sensorPreview: some View {
        if viewMode == .depth,
           let image = controller.depthPreview {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .background(.black)
        } else if viewMode == .confidence,
                  let image = controller.confidencePreview {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .background(.black)
        }
    }

    private var compactProgressPanel: some View {
        Button {
            withAnimation(.snappy) {
                showDetails.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: projectType.symbol)
                        .symbolRenderingMode(.hierarchical)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(stage.titleKey))
                            .font(.headline)

                        Text(
                            controller.coverage,
                            format: .percent.precision(.fractionLength(0))
                        )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if controller.recommendedReady {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Image(
                        systemName: showDetails
                            ? "chevron.up"
                            : "chevron.down"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                }

                ProgressView(value: controller.coverage)

                if showDetails {
                    expandedProgressDetails
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(14)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 20)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var expandedProgressDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            Text(LocalizedStringKey(stage.instructionKey))
                .font(.caption)
                .foregroundStyle(.secondary)

            Label(
                LocalizedStringKey(controller.captureGuidance.titleKey),
                systemImage: controller.captureGuidance.symbol
            )
            .font(.caption.weight(.semibold))

            if let recommendation = controller.missingViewpointRecommendation,
               appState.isEnabled(.coverageHeatmap) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("viewpoint.title")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(
                        String(
                            format: NSLocalizedString(
                                recommendation.directionKey,
                                comment: ""
                            ),
                            recommendation.azimuthDegrees
                        )
                    )
                    .font(.caption.weight(.semibold))

                    Text(LocalizedStringKey(recommendation.elevationKey))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 8
            ) {
                detailMetric(
                    "metric.tracking",
                    controller.trackingDescription
                )

                detailMetric(
                    "metric.confidence",
                    controller.confidence?.formatted(
                        .percent.precision(.fractionLength(0))
                    ) ?? "—"
                )

                detailMetric(
                    "metric.distance",
                    controller.centerDistanceMeters.map {
                        $0.formatted(
                            .number.precision(.fractionLength(2))
                        ) + " m"
                    } ?? "—"
                )

                detailMetric(
                    "coverage.surface",
                    controller.surfaceCoverageCells.isEmpty
                        ? "—"
                        : controller.surfaceCoverageScore.formatted(
                            .percent.precision(.fractionLength(0))
                        )
                )
            }

            if sourceRecorder.isRecording {
                Label(
                    "source.active",
                    systemImage: "archivebox.fill"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if measurementMode {
                Label(
                    "measure.active",
                    systemImage: "ruler"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func detailMetric(
        _ title: LocalizedStringKey,
        _ value: String
    ) -> some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.caption.bold())
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(8)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    private var optionsButton: some View {
        Button {
            showOptions = true
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "slider.horizontal.3")
                Text("scan.options")
                    .fontWeight(.semibold)

                if measurementMode ||
                    targetSelectionMode ||
                    showSurfaceHeatmap ||
                    sourceRecorder.isRecording ||
                    rgbdRecorder.isRecording {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
        }
        .buttonStyle(.borderedProminent)
        .background(
            .ultraThinMaterial,
            in: Capsule()
        )
    }

    private var interactionReticle: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.9), lineWidth: 1.5)
                .frame(width: 48, height: 48)

            Image(
                systemName: measurementMode
                    ? "plus"
                    : "scope"
            )
            .font(.caption.bold())
            .foregroundStyle(.white)
        }
        .shadow(radius: 3)
        .allowsHitTesting(false)
    }

    private var optionsSheet: some View {
        NavigationStack {
            List {
                Section("scan.session") {
                    Button {
                        isRunning.toggle()
                    } label: {
                        Label(
                            isRunning ? "scan.pause" : "scan.resume",
                            systemImage: isRunning
                                ? "pause.fill"
                                : "play.fill"
                        )
                    }

                    stageAction
                }

                Section("sensor.mode") {
                    ForEach(availableViewModes) { mode in
                        Button {
                            viewMode = mode
                            showOptions = false
                        } label: {
                            HStack {
                                Label(
                                    LocalizedStringKey(mode.titleKey),
                                    systemImage: mode.symbol
                                )

                                Spacer()

                                if viewMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                if projectType == .object {
                    objectOptions
                }

                Section("scan.projectTools") {
                    projectToolRows
                }

                if projectType == .video {
                    videoOptions
                }

                Section("quality.title") {
                    Picker(
                        "quality.title",
                        selection: $appState.captureQuality
                    ) {
                        ForEach(CaptureQualityMode.allCases) { mode in
                            Text(LocalizedStringKey(mode.titleKey))
                                .tag(mode)
                        }
                    }
                }
            }
            .navigationTitle("scan.options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.ok") {
                        showOptions = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var stageAction: some View {
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
                    persist(
                        stage: stage,
                        showConfirmation: false
                    )
                    stage = next
                    controller.reset(clearPointCloud: false)
                    showOptions = false
                } label: {
                    Label(
                        "scan.nextPass",
                        systemImage: "arrow.right.circle.fill"
                    )
                }
            }
        } else {
            Button {
                persist(
                    stage: stage,
                    showConfirmation: true
                )
                showOptions = false
            } label: {
                Label(
                    "scan.save",
                    systemImage: "square.and.arrow.down"
                )
            }
        }
    }

    @ViewBuilder
    private var objectOptions: some View {
        Section("target.title") {
            Button {
                controller.clearTarget()
                targetSelectionMode = true
                measurementMode = false
                showOptions = false
            } label: {
                Label(
                    controller.targetLocked
                        ? "target.reselect"
                        : "target.tapToLock",
                    systemImage: "scope"
                )
            }

            if controller.targetLocked {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("target.radius")
                        Spacer()
                        Text(
                            controller.targetRadiusMeters.formatted(
                                .number.precision(.fractionLength(2))
                            ) + " m"
                        )
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { controller.targetRadiusMeters },
                            set: { controller.setTargetRadius($0) }
                        ),
                        in: 0.20...3.00,
                        step: 0.05
                    )
                }

                Button(role: .destructive) {
                    controller.clearTarget()
                } label: {
                    Label(
                        "target.clear",
                        systemImage: "xmark.circle"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var projectToolRows: some View {
        ForEach(availableCaptureTools) { tool in
            switch tool {
            case .measurements:
                Button {
                    measurementMode.toggle()
                    targetSelectionMode = false

                    if !measurementMode {
                        controller.cancelMeasurementDraft()
                    }

                    showOptions = false
                } label: {
                    HStack {
                        Label(
                            "measure.title",
                            systemImage: "ruler"
                        )
                        Spacer()
                        if measurementMode {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                }

            case .scanHealth:
                NavigationLink {
                    ScanHealthReportView(
                        projectType: projectType,
                        stage: stage,
                        controller: controller
                    )
                } label: {
                    Label(
                        "health.title",
                        systemImage: "waveform.path.ecg"
                    )
                }

            case .coverageHeatmap:
                Toggle(
                    "coverage.show3d",
                    isOn: $showSurfaceHeatmap
                )

            case .pointCloudExport:
                Button {
                    exportPointCloud()
                } label: {
                    Label(
                        "export.ply",
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                }
                .disabled(
                    controller.densePointCount == 0 &&
                    controller.accumulatedPointCount == 0
                )

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label(
                            "export.share",
                            systemImage: "square.and.arrow.up"
                        )
                    }
                }

            case .sourceArchive:
                Button {
                    if sourceRecorder.isRecording {
                        sourceRecorder.stop()
                    } else {
                        startSourceArchiveIfNeeded(force: true)
                    }
                } label: {
                    Label(
                        sourceRecorder.isRecording
                            ? "source.stop"
                            : "source.start",
                        systemImage: sourceRecorder.isRecording
                            ? "archivebox.fill"
                            : "archivebox"
                    )
                }

            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var videoOptions: some View {
        Section("rgbd.title") {
            if rgbdRecorder.isRecording {
                LabeledContent("rgbd.recording") {
                    Text(rgbdRecorder.frameCount.formatted())
                        .monospacedDigit()
                }

                Button {
                    rgbdRecorder.stop()
                } label: {
                    Label(
                        "rgbd.stop",
                        systemImage: "stop.fill"
                    )
                }
            } else if rgbdRecorder.isFinalizing {
                HStack {
                    ProgressView()
                    Text("rgbd.finalizing")
                }
            } else {
                Button {
                    rgbdRecorder.start(projectID: projectID)
                } label: {
                    Label(
                        "rgbd.start",
                        systemImage: "record.circle"
                    )
                }
            }

            if let packageURL = rgbdRecorder.packageURL,
               !rgbdRecorder.isFinalizing {
                ShareLink(item: packageURL) {
                    Label(
                        "rgbd.share",
                        systemImage: "square.and.arrow.up"
                    )
                }
            }
        }
    }

    private var availableViewModes: [SensorViewMode] {
        var modes: [SensorViewMode] = [.camera]

        if appState.isEnabled(.featurePoints) {
            modes.append(.cameraPoints)
        }
        if appState.isEnabled(.meshView) {
            modes.append(.mesh)
        }
        if appState.isEnabled(.depthView) {
            modes.append(.depth)
        }
        if appState.isEnabled(.confidenceView) {
            modes.append(.confidence)
        }
        if appState.isEnabled(.rawInspector) {
            modes.append(.raw)
        }

        return modes
    }

    private var availableCaptureTools: [WorkspaceTool] {
        appState.captureTools.filter { tool in
            guard appState.isEnabled(tool) else { return false }

            if tool == .sourceArchive,
               projectType == .video {
                return false
            }

            return true
        }
    }

    private func startSourceArchiveIfNeeded(force: Bool = false) {
        guard projectType != .video,
              !sourceRecorder.isRecording,
              !sourceRecorder.isFinalizing,
              force || appState.isEnabled(.sourceArchive) else {
            return
        }

        sourceRecorder.start(
            projectID: projectID,
            destination: .projectSources(stage: stage.rawValue)
        )
    }

    private func persist(
        stage: CaptureStage,
        showConfirmation: Bool
    ) {
        let project = ScanProject(
            id: projectID,
            createdAt: projectCreatedAt,
            updatedAt: Date(),
            name: projectType.rawValue.capitalized,
            type: projectType,
            stage: stage,
            metrics: controller.snapshot,
            measurements: controller.measurements,
            surfaceCoverage: controller.surfaceCoverageCells.map {
                SurfaceCoverageRecord(
                    id: $0.id,
                    x: $0.position.x,
                    y: $0.position.y,
                    z: $0.position.z,
                    coverage: $0.coverage,
                    confidence: $0.confidence
                )
            },
            target: controller.targetRecord
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

                if !controller.surfaceCoverageCells.isEmpty {
                    scoreRow(
                        "coverage.surface",
                        controller.surfaceCoverageScore
                    )
                }

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
        if !controller.surfaceCoverageCells.isEmpty,
           controller.surfaceCoverageScore < 0.55 {
            return "health.recommend.surface"
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
