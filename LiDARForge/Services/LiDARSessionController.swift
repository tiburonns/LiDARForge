import ARKit
import Combine
import CoreGraphics
import CoreVideo
import Foundation
import simd
import UIKit

enum CaptureGuidance: String {
    case initializing
    case good
    case moveSlower
    case moveCloser
    case moveFarther
    case addVisualDetail
    case improveConfidence
    case changeViewpoint
    case ready
    case interrupted
    case coolDevice

    var titleKey: String {
        switch self {
        case .initializing: return "coach.initializing"
        case .good: return "coach.good"
        case .moveSlower: return "coach.moveSlower"
        case .moveCloser: return "coach.moveCloser"
        case .moveFarther: return "coach.moveFarther"
        case .addVisualDetail: return "coach.addVisualDetail"
        case .improveConfidence: return "coach.improveConfidence"
        case .changeViewpoint: return "coach.changeViewpoint"
        case .ready: return "coach.ready"
        case .interrupted: return "coach.interrupted"
        case .coolDevice: return "coach.coolDevice"
        }
    }

    var symbol: String {
        switch self {
        case .initializing: return "hourglass"
        case .good: return "viewfinder"
        case .moveSlower: return "tortoise"
        case .moveCloser: return "arrow.down.right.and.arrow.up.left"
        case .moveFarther: return "arrow.up.left.and.arrow.down.right"
        case .addVisualDetail: return "sparkles"
        case .improveConfidence: return "scope"
        case .changeViewpoint: return "arrow.triangle.2.circlepath"
        case .ready: return "checkmark.circle.fill"
        case .interrupted: return "pause.circle"
        case .coolDevice: return "thermometer.high"
        }
    }
}

struct DepthStatistics {
    let centerDistance: Double?
    let validRatio: Double

    static let unavailable = DepthStatistics(centerDistance: nil, validRatio: 0)
}

@MainActor
final class LiDARSessionController: ObservableObject {
    @Published private(set) var coverage: Double = 0
    @Published private(set) var confidence: Double?
    @Published private(set) var centerDistanceMeters: Double?
    @Published private(set) var depthValidRatio: Double = 0
    @Published private(set) var featurePointCount: Int = 0
    @Published private(set) var meshAnchorCount: Int = 0
    @Published private(set) var trackingDescription: String = "—"
    @Published private(set) var depthResolution: CGSize = .zero
    @Published private(set) var depthPreview: UIImage?
    @Published private(set) var confidencePreview: UIImage?
    @Published private(set) var captureGuidance: CaptureGuidance = .initializing
    @Published private(set) var motionSpeed: Double = 0
    @Published private(set) var isInterrupted = false
    @Published private(set) var sessionError: String?
    @Published private(set) var thermalDescription: String = "Nominal"
    @Published private(set) var recommendedReady = false
    @Published private(set) var accumulatedPointCount = 0
    @Published private(set) var densePointCount = 0
    @Published private(set) var targetLocked = false
    @Published private(set) var targetDistanceMeters: Double?
    @Published private(set) var targetRadiusMeters: Double = 0.75
    @Published private(set) var coverageSectors = Array(repeating: 0.0, count: 24)
    @Published private(set) var supportsDepth = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    @Published private(set) var supportsMesh = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)

    private var profile = CaptureProfile.sensor
    private var projectType: ProjectType?
    private var orientationBins = Set<String>()
    private var spatialCells = Set<String>()
    private var pointKeys = Set<PointKey>()
    private var pointCloudPoints: [SIMD3<Float>] = []
    private var densePointKeys = Set<PointKey>()
    private var densePointCloudPoints: [SIMD3<Float>] = []
    private var targetPosition: SIMD3<Float>?
    private var coverageSectorHits = Array(repeating: 0, count: 24)
    private var startedAt = Date()
    private var lastPosition: SIMD3<Float>?
    private var lastTimestamp: TimeInterval?
    private var lastMeaningfulMovement = Date()

    private struct PointKey: Hashable {
        let x: Int
        let y: Int
        let z: Int
    }

    func configure(for projectType: ProjectType) {
        self.projectType = projectType
        profile = projectType.captureProfile
        targetRadiusMeters = projectType == .object ? 0.75 : 1.50
    }

    func lockTarget(position: SIMD3<Float>, cameraPosition: SIMD3<Float>?) {
        targetPosition = position
        targetLocked = true
        coverageSectorHits = Array(repeating: 0, count: 24)
        coverageSectors = Array(repeating: 0, count: 24)

        if let cameraPosition {
            targetDistanceMeters = Double(simd_distance(position, cameraPosition))
        } else {
            targetDistanceMeters = nil
        }
    }

    func clearTarget() {
        targetPosition = nil
        targetLocked = false
        targetDistanceMeters = nil
        coverageSectorHits = Array(repeating: 0, count: 24)
        coverageSectors = Array(repeating: 0, count: 24)
    }

    func setTargetRadius(_ meters: Double) {
        targetRadiusMeters = min(max(meters, 0.20), 3.00)
    }

    func reset(clearPointCloud: Bool = false) {
        orientationBins.removeAll()
        spatialCells.removeAll()
        coverage = 0
        confidence = nil
        centerDistanceMeters = nil
        depthValidRatio = 0
        featurePointCount = 0
        meshAnchorCount = 0
        trackingDescription = "—"
        depthResolution = .zero
        depthPreview = nil
        confidencePreview = nil
        captureGuidance = .initializing
        motionSpeed = 0
        isInterrupted = false
        sessionError = nil
        recommendedReady = false
        startedAt = Date()
        lastPosition = nil
        lastTimestamp = nil
        lastMeaningfulMovement = Date()

        if clearPointCloud {
            pointKeys.removeAll(keepingCapacity: true)
            pointCloudPoints.removeAll(keepingCapacity: true)
            densePointKeys.removeAll(keepingCapacity: true)
            densePointCloudPoints.removeAll(keepingCapacity: true)
            accumulatedPointCount = 0
            densePointCount = 0
        }

        coverageSectorHits = Array(repeating: 0, count: 24)
        coverageSectors = Array(repeating: 0, count: 24)
    }

    func setInterrupted(_ interrupted: Bool) {
        isInterrupted = interrupted
        if interrupted {
            captureGuidance = .interrupted
        }
    }

    func setSessionError(_ message: String?) {
        sessionError = message
    }

    func update(
        featurePoints: [SIMD3<Float>],
        meshAnchors: Int,
        tracking: String,
        trackingIsNormal: Bool,
        yaw: Float,
        pitch: Float,
        cameraPosition: SIMD3<Float>,
        timestamp: TimeInterval,
        depthResolution: CGSize,
        confidence: Double?,
        depthStatistics: DepthStatistics,
        depthPreview: UIImage?,
        confidencePreview: UIImage?,
        densePoints: [SIMD3<Float>] = []
    ) {
        featurePointCount = featurePoints.count
        meshAnchorCount = meshAnchors
        trackingDescription = tracking
        self.depthResolution = depthResolution
        self.confidence = confidence
        centerDistanceMeters = depthStatistics.centerDistance
        depthValidRatio = depthStatistics.validRatio

        if let depthPreview {
            self.depthPreview = depthPreview
        }
        if let confidencePreview {
            self.confidencePreview = confidencePreview
        }

        updateMotion(position: cameraPosition, timestamp: timestamp)
        accumulate(points: featurePoints)
        accumulateDense(points: densePoints)

        let yawBin = Int(((Double(yaw) + .pi) / (2 * .pi) * 12).rounded(.down))
        let pitchBand = Int(((Double(pitch) + (.pi / 2)) / .pi * 3).rounded(.down))
        orientationBins.insert("\(max(0, min(11, yawBin))):\(max(0, min(2, pitchBand)))")

        let x = Int(floor(cameraPosition.x / profile.cellSize))
        let y = Int(floor(cameraPosition.y / profile.cellSize))
        let z = Int(floor(cameraPosition.z / profile.cellSize))
        spatialCells.insert("\(x):\(y):\(z)")

        let orientationScore = min(Double(orientationBins.count) / profile.orientationTarget, 1)
        let movementScore = min(Double(spatialCells.count) / profile.movementTarget, 1)
        let geometryScore = min(Double(meshAnchors) / profile.geometryTarget, 1)
        let timeScore = min(Date().timeIntervalSince(startedAt) / 45.0, 1)

        coverage = min(
            1,
            orientationScore * 0.35 +
            movementScore * 0.30 +
            geometryScore * 0.25 +
            timeScore * 0.10
        )

        thermalDescription = thermalStateDescription(ProcessInfo.processInfo.thermalState)

        let confidenceReady = confidence.map { $0 >= 0.45 } ?? true
        let depthReady = !supportsDepth || depthStatistics.validRatio >= 0.20
        recommendedReady =
            coverage >= profile.targetCoverage &&
            confidenceReady &&
            depthReady &&
            trackingIsNormal

        captureGuidance = guidance(
            trackingIsNormal: trackingIsNormal,
            confidence: confidence,
            centerDistance: depthStatistics.centerDistance,
            depthValidRatio: depthStatistics.validRatio,
            featurePointCount: featurePoints.count
        )
    }

    func bestPointCloudSnapshot() -> PointCloudSnapshot {
        if !densePointCloudPoints.isEmpty {
            return PointCloudSnapshot(
                points: densePointCloudPoints,
                source: .sceneDepth
            )
        }

        return PointCloudSnapshot(
            points: pointCloudPoints,
            source: .featurePoints
        )
    }

    private func updateMotion(position: SIMD3<Float>, timestamp: TimeInterval) {
        defer {
            lastPosition = position
            lastTimestamp = timestamp
        }

        guard let previous = lastPosition, let previousTime = lastTimestamp else {
            motionSpeed = 0
            return
        }

        let delta = max(timestamp - previousTime, 0.001)
        let distance = simd_distance(position, previous)
        motionSpeed = Double(distance) / delta

        if distance > 0.03 {
            lastMeaningfulMovement = Date()
        }
    }

    private func accumulate(points: [SIMD3<Float>]) {
        guard !points.isEmpty, pointCloudPoints.count < 50_000 else { return }

        for point in points {
            let key = PointKey(
                x: Int((point.x / 0.02).rounded()),
                y: Int((point.y / 0.02).rounded()),
                z: Int((point.z / 0.02).rounded())
            )

            if pointKeys.insert(key).inserted {
                pointCloudPoints.append(point)
                if pointCloudPoints.count >= 50_000 { break }
            }
        }

        accumulatedPointCount = pointCloudPoints.count
    }

    private func accumulateDense(points: [SIMD3<Float>]) {
        guard !points.isEmpty, densePointCloudPoints.count < 250_000 else {
            return
        }

        let radius = Float(targetRadiusMeters)
        var sectorsSeen = Set<Int>()

        // 2 cm world-space voxel deduplication keeps long captures bounded.
        for point in points {
            if projectType == .object, let targetPosition {
                let offset = point - targetPosition
                let distance = simd_length(offset)

                guard distance <= radius else { continue }

                if distance > 0.02 {
                    let azimuth = atan2(offset.x, offset.z)
                    let horizontal = sqrt(offset.x * offset.x + offset.z * offset.z)
                    let elevation = atan2(offset.y, horizontal)

                    var column = Int(
                        floor((Double(azimuth) + .pi) / (2 * .pi) * 8.0)
                    )
                    column = max(0, min(7, column))

                    let normalizedElevation =
                        (Double(elevation) + (.pi / 2)) / .pi
                    var row = Int(floor(normalizedElevation * 3.0))
                    row = max(0, min(2, row))

                    sectorsSeen.insert(row * 8 + column)
                }
            }

            let key = PointKey(
                x: Int((point.x / 0.02).rounded()),
                y: Int((point.y / 0.02).rounded()),
                z: Int((point.z / 0.02).rounded())
            )

            if densePointKeys.insert(key).inserted {
                densePointCloudPoints.append(point)
                if densePointCloudPoints.count >= 250_000 { break }
            }
        }

        if targetLocked, motionSpeed > 0.03 {
            for index in sectorsSeen {
                coverageSectorHits[index] = min(
                    coverageSectorHits[index] + 1,
                    10
                )
            }

            coverageSectors = coverageSectorHits.map {
                min(Double($0) / 6.0, 1.0)
            }
        }

        densePointCount = densePointCloudPoints.count
    }

    private func guidance(
        trackingIsNormal: Bool,
        confidence: Double?,
        centerDistance: Double?,
        depthValidRatio: Double,
        featurePointCount: Int
    ) -> CaptureGuidance {
        if isInterrupted {
            return .interrupted
        }

        switch ProcessInfo.processInfo.thermalState {
        case .serious, .critical:
            return .coolDevice
        default:
            break
        }

        if !trackingIsNormal {
            return trackingDescription == "Move slower" ? .moveSlower : .addVisualDetail
        }

        if motionSpeed > profile.maxSpeed {
            return .moveSlower
        }

        if let centerDistance {
            if centerDistance < profile.minDistance {
                return .moveFarther
            }
            if centerDistance > profile.maxDistance {
                return .moveCloser
            }
        }

        if supportsDepth && depthValidRatio < 0.20 {
            return .improveConfidence
        }

        if let confidence, confidence < 0.35 {
            return .improveConfidence
        }

        if featurePointCount < 45 {
            return .addVisualDetail
        }

        if recommendedReady {
            return .ready
        }

        if Date().timeIntervalSince(lastMeaningfulMovement) > 4 {
            return .changeViewpoint
        }

        return .good
    }

    private func thermalStateDescription(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    var snapshot: ScanMetricsSnapshot {
        ScanMetricsSnapshot(
            coverage: coverage,
            confidence: confidence,
            featurePointCount: featurePointCount,
            meshAnchorCount: meshAnchorCount,
            trackingDescription: trackingDescription,
            depthWidth: Int(depthResolution.width),
            depthHeight: Int(depthResolution.height),
            depthValidRatio: depthValidRatio,
            centerDistanceMeters: centerDistanceMeters,
            densePointCount: densePointCount,
            thermalDescription: thermalDescription,
            targetLocked: targetLocked
        )
    }
}

enum LiDARFrameProcessor {
    static func trackingDescription(_ state: ARCamera.TrackingState) -> String {
        switch state {
        case .normal:
            return "Normal"
        case .notAvailable:
            return "Unavailable"
        case .limited(let reason):
            switch reason {
            case .initializing: return "Initializing"
            case .excessiveMotion: return "Move slower"
            case .insufficientFeatures: return "Need more visual detail"
            case .relocalizing: return "Relocalizing"
            @unknown default: return "Limited"
            }
        }
    }

    static func isTrackingNormal(_ state: ARCamera.TrackingState) -> Bool {
        if case .normal = state { return true }
        return false
    }

    static func depthStatistics(from pixelBuffer: CVPixelBuffer?) -> DepthStatistics {
        guard let pixelBuffer else { return .unavailable }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return .unavailable
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let rowStride = bytesPerRow / MemoryLayout<Float32>.size
        let pointer = base.assumingMemoryBound(to: Float32.self)
        let step = max(1, min(width, height) / 48)

        let centerMinX = Int(Double(width) * 0.35)
        let centerMaxX = Int(Double(width) * 0.65)
        let centerMinY = Int(Double(height) * 0.35)
        let centerMaxY = Int(Double(height) * 0.65)

        var totalSamples = 0
        var validSamples = 0
        var centerSamples: [Float32] = []

        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                totalSamples += 1
                let value = pointer[y * rowStride + x]

                guard value.isFinite, value > 0 else { continue }
                validSamples += 1

                if x >= centerMinX, x <= centerMaxX,
                   y >= centerMinY, y <= centerMaxY {
                    centerSamples.append(value)
                }
            }
        }

        centerSamples.sort()
        let centerDistance: Double?
        if centerSamples.isEmpty {
            centerDistance = nil
        } else {
            centerDistance = Double(centerSamples[centerSamples.count / 2])
        }

        let validRatio = totalSamples > 0
            ? Double(validSamples) / Double(totalSamples)
            : 0

        return DepthStatistics(
            centerDistance: centerDistance,
            validRatio: validRatio
        )
    }

    static func confidenceScore(from pixelBuffer: CVPixelBuffer?) -> Double? {
        guard let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pointer = base.assumingMemoryBound(to: UInt8.self)

        var total = 0.0
        var samples = 0
        let step = max(1, min(width, height) / 48)

        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let value = pointer[y * bytesPerRow + x]
                total += min(Double(value), 2.0) / 2.0
                samples += 1
            }
        }

        return samples > 0 ? total / Double(samples) : nil
    }

    static func depthImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let rowStride = bytesPerRow / MemoryLayout<Float32>.size
        let pointer = base.assumingMemoryBound(to: Float32.self)

        var pixels = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let distance = pointer[y * rowStride + x]
                guard distance.isFinite, distance > 0 else { continue }

                let normalized = max(0, min((distance - 0.20) / 4.80, 1))
                pixels[y * width + x] = UInt8((1 - normalized) * 255)
            }
        }

        return grayscaleImage(bytes: pixels, width: width, height: height)
    }

    static func confidenceImage(from pixelBuffer: CVPixelBuffer?) -> UIImage? {
        guard let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pointer = base.assumingMemoryBound(to: UInt8.self)

        var pixels = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let level = min(pointer[y * bytesPerRow + x], 2)
                pixels[y * width + x] = UInt8(Double(level) / 2.0 * 255)
            }
        }

        return grayscaleImage(bytes: pixels, width: width, height: height)
    }

    private static func grayscaleImage(bytes: [UInt8], width: Int, height: Int) -> UIImage? {
        let data = Data(bytes)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            return nil
        }

        return UIImage(cgImage: image, scale: 1, orientation: .right)
    }
}
