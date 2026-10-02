import RealityKit
import SwiftUI

@MainActor
final class ObjectCaptureWorkflowModel: ObservableObject {
    @Published private(set) var isSupported = ObjectCaptureSession.isSupported
    @Published private(set) var state: ObjectCaptureSession.CaptureState = .initializing
    @Published private(set) var shotCount = 0
    @Published private(set) var completedPasses = 0
    @Published private(set) var passReady = false
    @Published private(set) var packageURL: URL?
    @Published var errorMessage: String?

    let session: ObjectCaptureSession?

    private var rootURL: URL?
    private var stateTask: Task<Void, Never>?
    private var shotsTask: Task<Void, Never>?
    private var passTask: Task<Void, Never>?

    init() {
        if ObjectCaptureSession.isSupported {
            session = ObjectCaptureSession()
        } else {
            session = nil
        }
    }

    deinit {
        stateTask?.cancel()
        shotsTask?.cancel()
        passTask?.cancel()
    }

    func startIfNeeded(projectID: UUID) {
        guard packageURL == nil,
              rootURL == nil,
              let session else {
            return
        }

        do {
            let base = try Self.objectCapturesRoot()
            let root = base.appendingPathComponent(
                "\(projectID.uuidString)-\(UUID().uuidString).lidarforge",
                isDirectory: true
            )

            try FileManager.default.createDirectory(
                at: root,
                withIntermediateDirectories: true
            )

            let images = root.appendingPathComponent(
                "images",
                isDirectory: true
            )
            let checkpoints = root.appendingPathComponent(
                "checkpoints",
                isDirectory: true
            )

            var configuration = ObjectCaptureSession.Configuration()
            configuration.checkpointDirectory = checkpoints
            configuration.isOverCaptureEnabled = false

            session.start(
                imagesDirectory: images,
                configuration: configuration
            )

            rootURL = root
            monitor(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginDetection() {
        guard let session else { return }
        if !session.startDetecting() {
            errorMessage = String(localized: "objectCapture.detectFailed")
        }
    }

    func beginCapture() {
        session?.startCapturing()
    }

    func togglePause() {
        guard let session else { return }
        if session.isPaused {
            session.resume()
        } else {
            session.pause()
        }
    }

    func requestManualImage() {
        guard let session,
              session.canRequestImageCapture else {
            return
        }
        session.requestImageCapture()
    }

    func beginNewPass() {
        guard let session else { return }
        session.beginNewScanPass()
        passReady = false
    }

    func beginPassAfterFlip() {
        guard let session else { return }
        session.beginNewScanPassAfterFlip()
        passReady = false
    }

    func finish() {
        session?.finish()
    }

    func cancel() {
        session?.cancel()
    }

    private func monitor(_ session: ObjectCaptureSession) {
        stateTask?.cancel()
        shotsTask?.cancel()
        passTask?.cancel()

        stateTask = Task { [weak self] in
            for await newState in session.stateUpdates {
                guard let self else { return }
                state = newState

                switch newState {
                case .completed:
                    finalizePackage()
                case .failed(let error):
                    errorMessage = error.localizedDescription
                default:
                    break
                }
            }
        }

        shotsTask = Task { [weak self] in
            for await count in session.numberOfShotsTakenUpdates {
                guard let self else { return }
                shotCount = count
            }
        }

        passTask = Task { [weak self] in
            for await complete in session.userCompletedScanPassUpdates {
                guard let self else { return }
                if complete, !passReady {
                    completedPasses += 1
                    passReady = true
                }
            }
        }
    }

    private func finalizePackage() {
        guard let rootURL else { return }

        let manifest: [String: Any] = [
            "formatVersion": 1,
            "captureType": "RealityKit ObjectCaptureSession",
            "shots": shotCount,
            "completedPasses": completedPasses,
            "completedAt": ISO8601DateFormatter().string(from: Date())
        ]

        do {
            let data = try JSONSerialization.data(
                withJSONObject: manifest,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(
                to: rootURL.appendingPathComponent("object-capture.json"),
                options: .atomic
            )
            packageURL = rootURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func objectCapturesRoot() throws -> URL {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let root = documents
            .appendingPathComponent("LiDARForge", isDirectory: true)
            .appendingPathComponent("ObjectCaptures", isDirectory: true)

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        return root
    }
}

struct ObjectCaptureProjectView: View {
    let projectID: UUID

    @StateObject private var model = ObjectCaptureWorkflowModel()
    @State private var showPointCloud = false

    init(projectID: UUID = UUID()) {
        self.projectID = projectID
    }

    var body: some View {
        Group {
            if !model.isSupported {
                unsupported
            } else if let session = model.session {
                ZStack {
                    if showPointCloud {
                        ObjectCapturePointCloudView(session: session)
                            .ignoresSafeArea()
                    } else {
                        ObjectCaptureView(session: session)
                            .ignoresSafeArea()
                    }

                    VStack(spacing: 12) {
                        statusCard
                        Spacer()
                        controls(session)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("objectCapture.title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.startIfNeeded(projectID: projectID)
        }
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

    private var unsupported: some View {
        ContentUnavailableView {
            Label(
                "objectCapture.unsupported.title",
                systemImage: "camera.macro.circle"
            )
        } description: {
            Text("objectCapture.unsupported.subtitle")
        } actions: {
            NavigationLink {
                ScannerView(
                    projectType: .object,
                    initialStage: .appearance
                )
            } label: {
                Text("objectCapture.useLiDAR")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(
                    "objectCapture.appearance",
                    systemImage: "camera.macro"
                )
                .font(.headline)

                Spacer()

                Text(stateLabel)
                    .font(.caption.bold())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, in: Capsule())
            }

            HStack(spacing: 14) {
                Label(
                    "\(model.shotCount)",
                    systemImage: "photo.on.rectangle"
                )

                Label(
                    "\(model.completedPasses)",
                    systemImage: "arrow.triangle.2.circlepath"
                )

                Spacer()

                if model.passReady {
                    Label(
                        "objectCapture.passComplete",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                }
            }
            .font(.caption)

            Text(instructionKey)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func controls(_ session: ObjectCaptureSession) -> some View {
        VStack(spacing: 8) {
            switch model.state {
            case .initializing:
                ProgressView("objectCapture.initializing")

            case .ready:
                Button {
                    model.beginDetection()
                } label: {
                    Label(
                        "objectCapture.detect",
                        systemImage: "scope"
                    )
                }
                .buttonStyle(.borderedProminent)

            case .detecting:
                Button {
                    model.beginCapture()
                } label: {
                    Label(
                        "objectCapture.capture",
                        systemImage: "camera.fill"
                    )
                }
                .buttonStyle(.borderedProminent)

            case .capturing:
                HStack {
                    Button {
                        model.togglePause()
                    } label: {
                        Label(
                            session.isPaused
                                ? "scan.resume"
                                : "scan.pause",
                            systemImage: session.isPaused
                                ? "play.fill"
                                : "pause.fill"
                        )
                    }
                    .buttonStyle(.bordered)

                    Button {
                        model.requestManualImage()
                    } label: {
                        Label(
                            "objectCapture.manualShot",
                            systemImage: "camera.circle"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(!session.canRequestImageCapture)

                    Button {
                        showPointCloud.toggle()
                    } label: {
                        Label(
                            showPointCloud
                                ? "objectCapture.cameraView"
                                : "objectCapture.pointCloud",
                            systemImage: showPointCloud
                                ? "camera"
                                : "point.3.filled.connected.trianglepath.dotted"
                        )
                    }
                    .buttonStyle(.bordered)
                }

                if model.passReady {
                    HStack {
                        Button {
                            model.beginNewPass()
                            showPointCloud = false
                        } label: {
                            Label(
                                "objectCapture.newPass",
                                systemImage: "arrow.triangle.2.circlepath"
                            )
                        }
                        .buttonStyle(.bordered)

                        Button {
                            model.beginPassAfterFlip()
                            showPointCloud = false
                        } label: {
                            Label(
                                "objectCapture.flip",
                                systemImage: "arrow.up.and.down.and.arrow.left.and.right"
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Button {
                    model.finish()
                } label: {
                    Label(
                        "objectCapture.finish",
                        systemImage: "checkmark.circle.fill"
                    )
                }
                .buttonStyle(.borderedProminent)

            case .finishing:
                ProgressView("objectCapture.finishing")

            case .completed:
                VStack(spacing: 8) {
                    Label(
                        "objectCapture.complete",
                        systemImage: "checkmark.seal.fill"
                    )
                    .font(.headline)

                    if let packageURL = model.packageURL {
                        ShareLink(item: packageURL) {
                            Label(
                                "objectCapture.share",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

            case .failed:
                Label(
                    "objectCapture.failed",
                    systemImage: "exclamationmark.triangle"
                )
                .padding()
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 14)
                )

            @unknown default:
                Label(
                    "objectCapture.failed",
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var stateLabel: LocalizedStringKey {
        switch model.state {
        case .initializing: return "objectCapture.state.initializing"
        case .ready: return "objectCapture.state.ready"
        case .detecting: return "objectCapture.state.detecting"
        case .capturing: return "objectCapture.state.capturing"
        case .finishing: return "objectCapture.state.finishing"
        case .completed: return "objectCapture.state.completed"
        case .failed: return "objectCapture.state.failed"
        @unknown default: return "objectCapture.state.failed"
        }
    }

    private var instructionKey: LocalizedStringKey {
        switch model.state {
        case .initializing:
            return "objectCapture.instruction.initializing"
        case .ready:
            return "objectCapture.instruction.ready"
        case .detecting:
            return "objectCapture.instruction.detecting"
        case .capturing:
            return model.passReady
                ? "objectCapture.instruction.passComplete"
                : "objectCapture.instruction.capturing"
        case .finishing:
            return "objectCapture.instruction.finishing"
        case .completed:
            return "objectCapture.instruction.completed"
        case .failed:
            return "objectCapture.instruction.failed"
        @unknown default:
            return "objectCapture.instruction.failed"
        }
    }
}
