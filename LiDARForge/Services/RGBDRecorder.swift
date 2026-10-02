import ARKit
import Combine
import CoreImage
import CoreMotion
import CoreVideo
import Foundation
import simd

enum RGBDRecordingDestination {
    case standaloneDataset
    case projectSources(stage: String)
}

private struct RGBDFrameMetadata: Codable {
    let index: Int
    let timestamp: TimeInterval
    let rgbFile: String
    let depthFile: String?
    let confidenceFile: String?
    let imageWidth: Int
    let imageHeight: Int
    let depthWidth: Int?
    let depthHeight: Int?
    let cameraTransform: [Float]
    let intrinsics: [Float]
}

private struct RGBDIMUSample: Codable {
    let timestamp: TimeInterval
    let attitudeQuaternion: [Double]
    let rotationRate: [Double]
    let userAcceleration: [Double]
    let gravity: [Double]
}

private struct RGBDDatasetManifest: Codable {
    let formatVersion: Int
    let createdAt: Date
    let finalizedAt: Date
    let frameCount: Int
    let captureKind: String
    let coordinateSystem: String
    let depthFormat: String
    let confidenceFormat: String
    let imuFormat: String
    let notes: [String]
}

final class RGBDRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isFinalizing = false
    @Published private(set) var frameCount = 0
    @Published private(set) var packageURL: URL?
    @Published private(set) var errorMessage: String?

    private let queue = DispatchQueue(
        label: "com.tiburonns.LiDARForge.rgbd-recorder",
        qos: .userInitiated
    )

    private let motionManager = CMMotionManager()
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.tiburonns.LiDARForge.imu-recorder"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private let ciContext = CIContext(options: [
        .cacheIntermediates: false
    ])

    private var activeRoot: URL?
    private var createdAt: Date?
    private var metadataHandle: FileHandle?
    private var imuHandle: FileHandle?
    private var internalFrameCount = 0
    private var acceptingFrames = false
    private var captureKind = "dataset"

    func start(
        projectID: UUID,
        destination: RGBDRecordingDestination = .standaloneDataset
    ) {
        guard !isRecording, !isFinalizing else { return }

        do {
            let root: URL

            switch destination {
            case .standaloneDataset:
                captureKind = "standalone-rgbd"
                root = try Self.datasetsRoot()
                    .appendingPathComponent(
                        "\(projectID.uuidString)-\(UUID().uuidString).lidarforge",
                        isDirectory: true
                    )

            case .projectSources(let stage):
                captureKind = "project-source-\(stage)"
                root = try Self.projectSourcesRoot(projectID: projectID)
                    .appendingPathComponent(
                        "\(stage)-\(UUID().uuidString)",
                        isDirectory: true
                    )
            }

            for folder in ["rgb", "depth", "confidence", "metadata"] {
                try FileManager.default.createDirectory(
                    at: root.appendingPathComponent(
                        folder,
                        isDirectory: true
                    ),
                    withIntermediateDirectories: true
                )
            }

            let framesURL = root
                .appendingPathComponent("metadata", isDirectory: true)
                .appendingPathComponent("frames.jsonl")

            let imuURL = root
                .appendingPathComponent("metadata", isDirectory: true)
                .appendingPathComponent("imu.jsonl")

            FileManager.default.createFile(
                atPath: framesURL.path,
                contents: nil
            )
            FileManager.default.createFile(
                atPath: imuURL.path,
                contents: nil
            )

            let frameHandle = try FileHandle(forWritingTo: framesURL)
            let motionHandle = try FileHandle(forWritingTo: imuURL)

            queue.sync {
                activeRoot = root
                createdAt = Date()
                metadataHandle = frameHandle
                imuHandle = motionHandle
                internalFrameCount = 0
                acceptingFrames = true
            }

            frameCount = 0
            packageURL = nil
            errorMessage = nil
            isRecording = true
            startMotionRecording()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func capture(
        frame: ARFrame,
        depth: ARDepthData?
    ) {
        guard isRecording else { return }

        queue.async { [weak self] in
            guard let self,
                  self.acceptingFrames,
                  let root = self.activeRoot else {
                return
            }

            do {
                let index = self.internalFrameCount
                let baseName = String(
                    format: "%06d",
                    index
                )

                let rgbRelative = "rgb/\(baseName).jpg"
                let rgbURL = root.appendingPathComponent(rgbRelative)

                try self.writeRGB(
                    frame.capturedImage,
                    to: rgbURL
                )

                var depthRelative: String?
                var confidenceRelative: String?
                var depthWidth: Int?
                var depthHeight: Int?

                if let depth {
                    depthWidth = CVPixelBufferGetWidth(depth.depthMap)
                    depthHeight = CVPixelBufferGetHeight(depth.depthMap)

                    let relative = "depth/\(baseName).f32"
                    try self.writeFloat32Buffer(
                        depth.depthMap,
                        to: root.appendingPathComponent(relative)
                    )
                    depthRelative = relative

                    if let confidenceMap = depth.confidenceMap {
                        let relative = "confidence/\(baseName).u8"
                        try self.writeUInt8Buffer(
                            confidenceMap,
                            to: root.appendingPathComponent(relative)
                        )
                        confidenceRelative = relative
                    }
                }

                let metadata = RGBDFrameMetadata(
                    index: index,
                    timestamp: frame.timestamp,
                    rgbFile: rgbRelative,
                    depthFile: depthRelative,
                    confidenceFile: confidenceRelative,
                    imageWidth: CVPixelBufferGetWidth(frame.capturedImage),
                    imageHeight: CVPixelBufferGetHeight(frame.capturedImage),
                    depthWidth: depthWidth,
                    depthHeight: depthHeight,
                    cameraTransform: Self.flatten(frame.camera.transform),
                    intrinsics: Self.flatten(frame.camera.intrinsics)
                )

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                let encoded = try encoder.encode(metadata)

                self.metadataHandle?.seekToEndOfFile()
                self.metadataHandle?.write(encoded)
                self.metadataHandle?.write(Data([0x0A]))

                self.internalFrameCount += 1
                let count = self.internalFrameCount

                DispatchQueue.main.async { [weak self] in
                    self?.frameCount = count
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func stop() {
        guard isRecording else { return }

        isRecording = false
        isFinalizing = true
        stopMotionRecording()

        queue.async { [weak self] in
            guard let self else { return }

            self.acceptingFrames = false

            do {
                try self.metadataHandle?.close()
                self.metadataHandle = nil

                try self.imuHandle?.close()
                self.imuHandle = nil

                guard let root = self.activeRoot,
                      let createdAt = self.createdAt else {
                    throw CocoaError(.fileNoSuchFile)
                }

                let manifest = RGBDDatasetManifest(
                    formatVersion: 2,
                    createdAt: createdAt,
                    finalizedAt: Date(),
                    frameCount: self.internalFrameCount,
                    captureKind: self.captureKind,
                    coordinateSystem: "ARKit world coordinates; camera looks toward -Z",
                    depthFormat: "Float32 meters, row-major, little-endian, tightly packed",
                    confidenceFormat: "UInt8 ARKit confidence levels 0...2, row-major",
                    imuFormat: "JSONL CoreMotion device-motion samples",
                    notes: [
                        "RGB JPEG frames retain the camera sensor orientation.",
                        "Per-frame camera transform and intrinsics are stored in metadata/frames.jsonl.",
                        "Depth and confidence files use dimensions stored in each frame metadata record.",
                        "Device-motion attitude, rotation rate, gravity, and user acceleration are stored in metadata/imu.jsonl when available."
                    ]
                )

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(manifest)

                try data.write(
                    to: root.appendingPathComponent("dataset.json"),
                    options: .atomic
                )

                DispatchQueue.main.async { [weak self] in
                    self?.packageURL = root
                    self?.isFinalizing = false
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = error.localizedDescription
                    self?.isFinalizing = false
                }
            }

            self.activeRoot = nil
            self.createdAt = nil
        }
    }

    private func startMotionRecording() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: motionQueue
        ) { [weak self] motion, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = error.localizedDescription
                }
                return
            }

            guard let motion,
                  self.isRecording,
                  let handle = self.imuHandle else {
                return
            }

            let quaternion = motion.attitude.quaternion
            let rotation = motion.rotationRate
            let acceleration = motion.userAcceleration
            let gravity = motion.gravity

            let sample = RGBDIMUSample(
                timestamp: motion.timestamp,
                attitudeQuaternion: [
                    quaternion.x,
                    quaternion.y,
                    quaternion.z,
                    quaternion.w
                ],
                rotationRate: [
                    rotation.x,
                    rotation.y,
                    rotation.z
                ],
                userAcceleration: [
                    acceleration.x,
                    acceleration.y,
                    acceleration.z
                ],
                gravity: [
                    gravity.x,
                    gravity.y,
                    gravity.z
                ]
            )

            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                let data = try encoder.encode(sample)
                handle.seekToEndOfFile()
                handle.write(data)
                handle.write(Data([0x0A]))
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func stopMotionRecording() {
        motionManager.stopDeviceMotionUpdates()
        motionQueue.waitUntilAllOperationsAreFinished()
    }

    private func writeRGB(
        _ pixelBuffer: CVPixelBuffer,
        to url: URL
    ) throws {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let data = ciContext.jpegRepresentation(
            of: image,
            colorSpace: colorSpace,
            options: [
                kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.92
            ]
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try data.write(to: url, options: .atomic)
    }

    private func writeFloat32Buffer(
        _ pixelBuffer: CVPixelBuffer,
        to url: URL
    ) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw CocoaError(.fileReadUnknown)
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let rowBytes = width * MemoryLayout<Float32>.size

        var data = Data(capacity: rowBytes * height)

        for row in 0..<height {
            data.append(
                Data(
                    bytes: base.advanced(by: row * bytesPerRow),
                    count: rowBytes
                )
            )
        }

        try data.write(to: url, options: .atomic)
    }

    private func writeUInt8Buffer(
        _ pixelBuffer: CVPixelBuffer,
        to url: URL
    ) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw CocoaError(.fileReadUnknown)
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        var data = Data(capacity: width * height)

        for row in 0..<height {
            data.append(
                Data(
                    bytes: base.advanced(by: row * bytesPerRow),
                    count: width
                )
            )
        }

        try data.write(to: url, options: .atomic)
    }

    private static func datasetsRoot() throws -> URL {
        guard let documents = documentsRoot() else {
            throw CocoaError(.fileNoSuchFile)
        }

        let root = documents
            .appendingPathComponent("LiDARForge", isDirectory: true)
            .appendingPathComponent("Datasets", isDirectory: true)

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        return root
    }

    private static func projectSourcesRoot(
        projectID: UUID
    ) throws -> URL {
        guard let documents = documentsRoot() else {
            throw CocoaError(.fileNoSuchFile)
        }

        let root = documents
            .appendingPathComponent("LiDARForge", isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
            .appendingPathComponent("sources", isDirectory: true)

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        return root
    }

    private static func documentsRoot() -> URL? {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first
    }

    private static func flatten(_ matrix: simd_float4x4) -> [Float] {
        [
            matrix.columns.0.x, matrix.columns.0.y,
            matrix.columns.0.z, matrix.columns.0.w,
            matrix.columns.1.x, matrix.columns.1.y,
            matrix.columns.1.z, matrix.columns.1.w,
            matrix.columns.2.x, matrix.columns.2.y,
            matrix.columns.2.z, matrix.columns.2.w,
            matrix.columns.3.x, matrix.columns.3.y,
            matrix.columns.3.z, matrix.columns.3.w
        ]
    }

    private static func flatten(_ matrix: simd_float3x3) -> [Float] {
        [
            matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z,
            matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z,
            matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z
        ]
    }
}
