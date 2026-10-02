import ARKit
import RoomPlan
import SwiftUI

struct RoomPlanSummary {
    let walls: Int
    let doors: Int
    let windows: Int
    let openings: Int
    let objects: Int
    let floors: Int
}

@MainActor
final class RoomPlanCaptureModel: ObservableObject {
    @Published private(set) var isSupported = RoomCaptureSession.isSupported
    @Published private(set) var isComplete = false
    @Published private(set) var summary: RoomPlanSummary?
    @Published private(set) var exportURL: URL?
    @Published var errorMessage: String?

    func complete(with room: CapturedRoom) {
        summary = RoomPlanSummary(
            walls: room.walls.count,
            doors: room.doors.count,
            windows: room.windows.count,
            openings: room.openings.count,
            objects: room.objects.count,
            floors: room.floors.count
        )

        do {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "LiDARForgeRoomPlan",
                    isDirectory: true
                )

            try FileManager.default.createDirectory(
                at: root,
                withIntermediateDirectories: true
            )

            let url = root.appendingPathComponent(
                "LiDARForge-Room-\(room.identifier.uuidString).usdz"
            )

            try room.export(
                to: url,
                exportOptions: .mesh
            )

            exportURL = url
            isComplete = true
        } catch {
            errorMessage = error.localizedDescription
            isComplete = true
        }
    }

    func reset() {
        isComplete = false
        summary = nil
        exportURL = nil
        errorMessage = nil
    }
}

struct RoomPlanProjectView: View {
    let projectType: ProjectType

    @StateObject private var model = RoomPlanCaptureModel()
    @State private var isRunning = true

    var body: some View {
        Group {
            if model.isSupported {
                ZStack {
                    RoomPlanCaptureContainer(
                        model: model,
                        isRunning: $isRunning
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 12) {
                        roomPlanHeader

                        Spacer()

                        if model.isComplete {
                            resultCard
                        } else {
                            captureControls
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "roomplan.unsupported.title",
                    systemImage: "square.3.layers.3d.slash",
                    description: Text("roomplan.unsupported.subtitle")
                )
            }
        }
        .navigationTitle("roomplan.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "LiDARForge",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var roomPlanHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("roomplan.structure", systemImage: "house.and.flag")
                    .font(.headline)

                Spacer()

                Text(LocalizedStringKey(projectType.titleKey))
                    .font(.caption.bold())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, in: Capsule())
            }

            Text("roomplan.instructions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var captureControls: some View {
        HStack {
            Label("roomplan.scanActive", systemImage: "wave.3.right.circle")
                .font(.caption.bold())

            Spacer()

            Button {
                isRunning = false
            } label: {
                Label("roomplan.finish", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("roomplan.complete", systemImage: "checkmark.seal.fill")
                .font(.headline)

            if let summary = model.summary {
                Grid(horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        summaryMetric("roomplan.walls", summary.walls)
                        summaryMetric("roomplan.doors", summary.doors)
                        summaryMetric("roomplan.windows", summary.windows)
                    }

                    GridRow {
                        summaryMetric("roomplan.openings", summary.openings)
                        summaryMetric("roomplan.objects", summary.objects)
                        summaryMetric("roomplan.floors", summary.floors)
                    }
                }
            }

            HStack {
                if let exportURL = model.exportURL {
                    ShareLink(item: exportURL) {
                        Label("roomplan.shareUSDZ", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                NavigationLink {
                    ScannerView(
                        projectType: projectType,
                        initialStage: .detail
                    )
                } label: {
                    Label("roomplan.continueDetail", systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                model.reset()
                isRunning = true
            } label: {
                Label("roomplan.rescan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func summaryMetric(
        _ key: LocalizedStringKey,
        _ value: Int
    ) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline.monospacedDigit())
            Text(key)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RoomPlanCaptureContainer: UIViewRepresentable {
    @ObservedObject var model: RoomPlanCaptureModel
    @Binding var isRunning: Bool

    func makeCoordinator() -> RoomPlanCaptureCoordinator {
        RoomPlanCaptureCoordinator(model: model)
    }

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        view.isModelEnabled = true
        view.delegate = context.coordinator
        context.coordinator.attach(to: view)
        context.coordinator.setRunning(isRunning)
        return view
    }

    func updateUIView(
        _ uiView: RoomCaptureView,
        context: Context
    ) {
        context.coordinator.setRunning(isRunning)
    }

    static func dismantleUIView(
        _ uiView: RoomCaptureView,
        coordinator: RoomPlanCaptureCoordinator
    ) {
        coordinator.stop()
        uiView.delegate = nil
    }
}

@objc(LiDARForgeRoomPlanCaptureCoordinator)
private final class RoomPlanCaptureCoordinator: NSObject, RoomCaptureViewDelegate {
    private let model: RoomPlanCaptureModel
    private weak var captureView: RoomCaptureView?
    private var running = false

    init(model: RoomPlanCaptureModel) {
        self.model = model
        super.init()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func encode(with coder: NSCoder) {
        // The delegate is never intentionally archived by LiDARForge.
    }

    func attach(to view: RoomCaptureView) {
        captureView = view
    }

    func setRunning(_ shouldRun: Bool) {
        guard shouldRun != running,
              let captureView else {
            return
        }

        running = shouldRun

        if shouldRun {
            captureView.captureSession.run(
                configuration: RoomCaptureSession.Configuration()
            )
        } else {
            captureView.captureSession.stop()
        }
    }

    func stop() {
        guard running else { return }
        captureView?.captureSession.stop()
        running = false
    }

    func captureView(
        shouldPresent roomDataForProcessing: CapturedRoomData,
        error: Error?
    ) -> Bool {
        if let error {
            Task { @MainActor [weak model] in
                model?.errorMessage = error.localizedDescription
            }
        }

        return true
    }

    func captureView(
        didPresent processedResult: CapturedRoom,
        error: Error?
    ) {
        if let error {
            Task { @MainActor [weak model] in
                model?.errorMessage = error.localizedDescription
            }
        }

        Task { @MainActor [weak model] in
            model?.complete(with: processedResult)
        }
    }
}


@MainActor
final class BuildingRoomPlanCaptureModel: ObservableObject {
    let arSession = ARSession()

    @Published private(set) var isSupported = RoomCaptureSession.isSupported
    @Published private(set) var roomCount = 0
    @Published private(set) var lastSummary: RoomPlanSummary?
    @Published private(set) var roomReady = false
    @Published private(set) var isBuildingStructure = false
    @Published private(set) var isStructureComplete = false
    @Published private(set) var structureExportURL: URL?
    @Published var errorMessage: String?

    private var rooms: [CapturedRoom] = []

    func addRoom(_ room: CapturedRoom) {
        rooms.append(room)
        roomCount = rooms.count
        lastSummary = RoomPlanSummary(
            walls: room.walls.count,
            doors: room.doors.count,
            windows: room.windows.count,
            openings: room.openings.count,
            objects: room.objects.count,
            floors: room.floors.count
        )
        roomReady = true
    }

    func prepareNextRoom() {
        roomReady = false
        lastSummary = nil
        errorMessage = nil
    }

    func buildStructure() async {
        guard !rooms.isEmpty else { return }

        isBuildingStructure = true
        defer { isBuildingStructure = false }

        do {
            let builder = StructureBuilder(
                options: [.beautifyObjects]
            )

            let structure = try await builder.capturedStructure(
                from: rooms
            )

            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "LiDARForgeStructures",
                    isDirectory: true
                )

            try FileManager.default.createDirectory(
                at: root,
                withIntermediateDirectories: true
            )

            let url = root.appendingPathComponent(
                "LiDARForge-Structure-\(structure.identifier.uuidString).usdz"
            )

            try structure.export(
                to: url,
                exportOptions: .mesh
            )

            structureExportURL = url
            isStructureComplete = true
            roomReady = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetAll() {
        arSession.pause()
        rooms.removeAll()
        roomCount = 0
        lastSummary = nil
        roomReady = false
        isStructureComplete = false
        structureExportURL = nil
        errorMessage = nil
    }
}

struct BuildingRoomPlanProjectView: View {
    @StateObject private var model = BuildingRoomPlanCaptureModel()
    @State private var isRunning = true

    var body: some View {
        Group {
            if model.isSupported {
                ZStack {
                    BuildingRoomPlanCaptureContainer(
                        model: model,
                        isRunning: $isRunning
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 12) {
                        buildingHeader
                        Spacer()

                        if model.isStructureComplete {
                            structureResult
                        } else if model.roomReady {
                            roomResult
                        } else {
                            captureControls
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "roomplan.unsupported.title",
                    systemImage: "building.2.crop.circle.badge.exclamationmark",
                    description: Text("roomplan.unsupported.subtitle")
                )
            }
        }
        .navigationTitle("building.capture.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "LiDARForge",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var buildingHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(
                    "building.capture.structure",
                    systemImage: "building.2"
                )
                .font(.headline)

                Spacer()

                Text(
                    String(
                        format: String(localized: "building.capture.roomCount"),
                        model.roomCount
                    )
                )
                .font(.caption.bold())
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.thinMaterial, in: Capsule())
            }

            Text("building.capture.instructions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var captureControls: some View {
        HStack {
            Label(
                "building.capture.active",
                systemImage: "wave.3.right.circle"
            )
            .font(.caption.bold())

            Spacer()

            Button {
                isRunning = false
            } label: {
                Label("building.capture.finishRoom", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var roomResult: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                "building.capture.roomSaved",
                systemImage: "checkmark.circle.fill"
            )
            .font(.headline)

            if let summary = model.lastSummary {
                HStack {
                    compactMetric("roomplan.walls", summary.walls)
                    compactMetric("roomplan.doors", summary.doors)
                    compactMetric("roomplan.windows", summary.windows)
                    compactMetric("roomplan.objects", summary.objects)
                }
            }

            HStack {
                Button {
                    model.prepareNextRoom()
                    isRunning = true
                } label: {
                    Label(
                        "building.capture.nextRoom",
                        systemImage: "plus.square"
                    )
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button {
                    Task {
                        await model.buildStructure()
                    }
                } label: {
                    if model.isBuildingStructure {
                        ProgressView()
                    } else {
                        Label(
                            "building.capture.finishStructure",
                            systemImage: "square.stack.3d.up.fill"
                        )
                    }
                }
                .buttonStyle(.bordered)
                .disabled(model.isBuildingStructure)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var structureResult: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                "building.capture.complete",
                systemImage: "checkmark.seal.fill"
            )
            .font(.headline)

            Text(
                String(
                    format: String(localized: "building.capture.mergedRooms"),
                    model.roomCount
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack {
                if let url = model.structureExportURL {
                    ShareLink(item: url) {
                        Label(
                            "building.capture.shareUSDZ",
                            systemImage: "square.and.arrow.up"
                        )
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                NavigationLink {
                    ScannerView(
                        projectType: .building,
                        initialStage: .detail
                    )
                } label: {
                    Label(
                        "roomplan.continueDetail",
                        systemImage: "arrow.right"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func compactMetric(
        _ key: LocalizedStringKey,
        _ value: Int
    ) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.caption.bold())
                .monospacedDigit()

            Text(key)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BuildingRoomPlanCaptureContainer: UIViewRepresentable {
    @ObservedObject var model: BuildingRoomPlanCaptureModel
    @Binding var isRunning: Bool

    func makeCoordinator() -> BuildingRoomPlanCaptureCoordinator {
        BuildingRoomPlanCaptureCoordinator(model: model)
    }

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(
            frame: .zero,
            arSession: model.arSession
        )
        view.isModelEnabled = true
        view.delegate = context.coordinator
        context.coordinator.attach(to: view)
        context.coordinator.setRunning(isRunning)
        return view
    }

    func updateUIView(
        _ uiView: RoomCaptureView,
        context: Context
    ) {
        context.coordinator.setRunning(isRunning)
    }

    static func dismantleUIView(
        _ uiView: RoomCaptureView,
        coordinator: BuildingRoomPlanCaptureCoordinator
    ) {
        coordinator.stop()
        uiView.delegate = nil
    }
}

@objc(LiDARForgeBuildingRoomPlanCaptureCoordinator)
private final class BuildingRoomPlanCaptureCoordinator: NSObject, RoomCaptureViewDelegate {
    private let model: BuildingRoomPlanCaptureModel
    private weak var captureView: RoomCaptureView?
    private var running = false

    init(model: BuildingRoomPlanCaptureModel) {
        self.model = model
        super.init()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func encode(with coder: NSCoder) {
        // The delegate is never intentionally archived by LiDARForge.
    }

    func attach(to view: RoomCaptureView) {
        captureView = view
    }

    func setRunning(_ shouldRun: Bool) {
        guard shouldRun != running,
              let captureView else {
            return
        }

        running = shouldRun

        if shouldRun {
            captureView.captureSession.run(
                configuration: RoomCaptureSession.Configuration()
            )
        } else {
            captureView.captureSession.stop(
                pauseARSession: false
            )
        }
    }

    func stop() {
        guard running else { return }
        captureView?.captureSession.stop(
            pauseARSession: false
        )
        running = false
    }

    func captureView(
        shouldPresent roomDataForProcessing: CapturedRoomData,
        error: Error?
    ) -> Bool {
        if let error {
            Task { @MainActor [weak model] in
                model?.errorMessage = error.localizedDescription
            }
        }
        return true
    }

    func captureView(
        didPresent processedResult: CapturedRoom,
        error: Error?
    ) {
        if let error {
            Task { @MainActor [weak model] in
                model?.errorMessage = error.localizedDescription
            }
        }

        Task { @MainActor [weak model] in
            model?.addRoom(processedResult)
        }
    }
}
