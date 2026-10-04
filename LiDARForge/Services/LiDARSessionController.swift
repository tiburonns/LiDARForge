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
    case lockTarget
    case fillCoverage
    case holdSteady
    case improveLighting
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
        case .lockTarget: return "coach.lockTarget"
        case .fillCoverage: return "coach.fillCoverage"
        case .holdSteady: return "coach.holdSteady"
        case .improveLighting: return "coach.improveLighting"
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
        case .lockTarget: return "scope"
        case .fillCoverage: return "arrow.triangle.2.circlepath"
        case .holdSteady: return "camera.metering.center.weighted"
        case .improveLighting: return "sun.max.trianglebadge.exclamationmark"
        case .addVisualDetail: return "sparkles"
        case .improveConfidence: return "scope"
        case .changeViewpoint: return "arrow.triangle.2.circlepath"
        case .ready: return "checkmark.circle.fill"
        case .interrupted: return "pause.circle"
        case .coolDevice: return "thermometer.high"
        }
    }
}

struct SpatialMeasurement: Identifiable, Codable {
    let id: UUID
    let distanceMeters: Double
    let createdAt: Date

    init(
        id: UUID = UUID(),
        distanceMeters: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.distanceMeters = distanceMeters
        self.createdAt = createdAt
    }
}

struct DepthStatistics {
    let centerDistance: Double?
    let validRatio: Double

    static let unavailable = DepthStatistics(centerDistance: nil, validRatio: 0)
}

struct SurfaceCoverageCell: Identifiable {
    let id: String
    let position: SIMD3<Float>
    let coverage: Double
    let confidence: Double
}

struct MissingViewpointRecommendation {
    let directionKey: String
    let azimuthDegrees: Int
    let elevationKey: String
    let coverage: Double
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
    @Published private(set) var cameraPreview: UIImage?
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
    @Published private(set) var surfaceCoverageCells: [SurfaceCoverageCell] = []
    @Published private(set) var surfaceCoverageScore: Double = 0
    @Published private(set) var missingViewpointRecommendation: MissingViewpointRecommendation?
    @Published private(set) var measurements: [SpatialMeasurement] = []
    @Published private(set) var measurementDraftPointCount = 0
    @Published private(set) var exposureDurationSeconds: Double = 0
    @Published private(set) var exposureOffset: Float = 0
    @Published private(set) var cameraPosition = SIMD3<Float>.zero
    @Published private(set) var cameraYaw: Float = 0
    @Published private(set) var cameraPitch: Float = 0
    @Published private(set) var frameTimestamp: TimeInterval = 0
    @Published private(set) var worldMapData: Data?
    @Published private(set) var worldMapSaveRequestID: UUID?
    @Published private(set) var supportsDepth = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    @Published private(set) var supportsMesh = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)

    private var profile = CaptureProfile.sensor
    private var projectType: ProjectType?
    private var captureStage: CaptureStage = .structure
    private var orientationBins = Set<String>()
    private var spatialCells = Set<String>()
    private var pointKeys = Set<PointKey>()
    private var pointCloudPoints: [SIMD3<Float>] = []
    private var densePointKeys = Set<PointKey>()
    private var densePointCloudPoints: [SIMD3<Float>] = []
    private var targetPosition: SIMD3<Float>?
    private var coverageSectorHits = Array(repeating: 0, count: 24)
    private var surfaceCoverageStates: [PointKey: SurfaceCoverageState] = [:]
    private var measurementStart: SIMD3<Float>?
    private var startedAt = Date()
    private var lastPosition: SIMD3<Float>?
    private var lastTimestamp: TimeInterval?
    private var lastMeaningfulMovement = Date()

    private struct PointKey: Hashable {
        let x: Int
        let y: Int
        let z: Int

        var id: String { "\(x):\(y):\(z)" }
    }

    private struct SurfaceCoverageState {
        var position: SIMD3<Float>
        var observations: Int
        var confidenceTotal: Double

        var coverage: Double {
            min(Double(observations) / 5.0, 1.0)
        }

        var confidence: Double {
            guard observations > 0 else { return 0 }
            return min(max(confidenceTotal / Double(observations), 0), 1)
        }
    }

    func configure(for projectType: ProjectType) {
        self.projectType = projectType
        profile = projectType.captureProfile
        targetRadiusMeters = projectType == .object ? 0.75 : 1.50
    }

    func setStage(_ stage: CaptureStage) {
        captureStage = stage
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
        measurementStart = nil
        measurementDraftPointCount = 0
    }

    func setTargetRadius(_ meters: Double) {
        targetRadiusMeters = min(max(meters, 0.20), 3.00)
    }

    func addMeasurementPoint(_ position: SIMD3<Float>) {
        if let start = measurementStart {
            let distance = Double(simd_distance(start, position))
            measurements.insert(
                SpatialMeasurement(distanceMeters: distance),
                at: 0
            )
            if measurements.count > 20 {
                measurements.removeLast(measurements.count - 20)
            }
            measurementStart = nil
            measurementDraftPointCount = 0
        } else {
            measurementStart = position
            measurementDraftPointCount = 1
        }
    }

    func cancelMeasurementDraft() {
        measurementStart = nil
        measurementDraftPointCount = 0
    }

    func clearMeasurements() {
        measurementStart = nil
        measurementDraftPointCount = 0
        measurements.removeAll()
    }

    func restoreMeasurements(_ saved: [SpatialMeasurement]) {
        guard measurements.isEmpty else { return }
        measurements = Array(saved.prefix(20))
    }

    func restoreSurfaceCoverage(
        _ saved: [SurfaceCoverageRecord]
    ) {
        guard surfaceCoverageStates.isEmpty else { return }

        let voxelSize: Float = projectType == .object ? 0.06 : 0.12

        for record in saved {
            let position = SIMD3<Float>(
                record.x,
                record.y,
                record.z
            )
            let key = PointKey(
                x: Int((position.x / voxelSize).rounded()),
                y: Int((position.y / voxelSize).rounded()),
                z: Int((position.z / voxelSize).rounded())
            )

            let observations = max(
                0,
                min(12, Int((record.coverage * 5.0).rounded()))
            )

            surfaceCoverageStates[key] = SurfaceCoverageState(
                position: position,
                observations: observations,
                confidenceTotal:
                    record.confidence * Double(max(observations, 1))
            )
        }

        refreshSurfaceCoveragePublishedState()
    }

    func restoreTarget(_ target: ScanTargetRecord) {
        targetPosition = SIMD3<Float>(
            target.x,
            target.y,
            target.z
        )
        targetRadiusMeters = min(
            max(target.radiusMeters, 0.20),
            3.00
        )
        targetLocked = true
    }

    var targetRecord: ScanTargetRecord? {
        guard let targetPosition, targetLocked else {
            return nil
        }

        return ScanTargetRecord(
            x: targetPosition.x,
            y: targetPosition.y,
            z: targetPosition.z,
            radiusMeters: targetRadiusMeters
        )
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
        cameraPreview = nil
        captureGuidance = .initializing
        motionSpeed = 0
        cameraPosition = .zero
        cameraYaw = 0
        cameraPitch = 0
        frameTimestamp = 0
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
        surfaceCoverageStates.removeAll(keepingCapacity: true)
        surfaceCoverageCells = []
        surfaceCoverageScore = 0
        missingViewpointRecommendation = nil
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

    func requestWorldMapSave() {
        worldMapSaveRequestID = UUID()
    }

    func receiveWorldMapData(_ data: Data) {
        worldMapData = data
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
        exposureDuration: TimeInterval,
        exposureOffset: Float,
        depthStatistics: DepthStatistics,
        depthPreview: UIImage?,
        confidencePreview: UIImage?,
        cameraPreview: UIImage? = nil,
        densePoints: [SIMD3<Float>] = [],
        meshSurfacePoints: [SIMD3<Float>] = []
    ) {
        featurePointCount = featurePoints.count
        meshAnchorCount = meshAnchors
        trackingDescription = tracking
        self.depthResolution = depthResolution
        self.confidence = confidence
        exposureDurationSeconds = exposureDuration
        self.exposureOffset = exposureOffset
        self.cameraPosition = cameraPosition
        cameraYaw = yaw
        cameraPitch = pitch
        frameTimestamp = timestamp
        centerDistanceMeters = depthStatistics.centerDistance
        depthValidRatio = depthStatistics.validRatio

        if let depthPreview {
            self.depthPreview = depthPreview
        }
        if let confidencePreview {
            self.confidencePreview = confidencePreview
        }
        if let cameraPreview {
            self.cameraPreview = cameraPreview
        }

        updateMotion(position: cameraPosition, timestamp: timestamp)
        accumulate(points: featurePoints)
        accumulateDense(points: densePoints)
        updateSurfaceCoverage(
            meshPoints: meshSurfacePoints,
            observedPoints: densePoints,
            confidence: confidence
        )

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

        let baseCoverage = min(
            1,
            orientationScore * 0.35 +
            movementScore * 0.30 +
            geometryScore * 0.25 +
            timeScore * 0.10
        )

        let directionalCoverage = coverageSectors.isEmpty
            ? 0
            : coverageSectors.reduce(0, +) / Double(coverageSectors.count)

        if projectType == .object, targetLocked {
            let surfaceWeight = surfaceCoverageCells.isEmpty ? 0.0 : 0.20
            let baseWeight = surfaceCoverageCells.isEmpty ? 0.60 : 0.45
            let directionalWeight = surfaceCoverageCells.isEmpty ? 0.40 : 0.35

            coverage = min(
                1,
                baseCoverage * baseWeight +
                directionalCoverage * directionalWeight +
                surfaceCoverageScore * surfaceWeight
            )
        } else if !surfaceCoverageCells.isEmpty {
            coverage = min(
                1,
                baseCoverage * 0.75 +
                surfaceCoverageScore * 0.25
            )
        } else {
            coverage = baseCoverage
        }

        thermalDescription = thermalStateDescription(ProcessInfo.processInfo.thermalState)

        let confidenceReady = confidence.map { $0 >= 0.45 } ?? true
        let depthReady = !supportsDepth || depthStatistics.validRatio >= 0.20
        let wellCoveredSectors = coverageSectors.filter { $0 >= 0.66 }.count
        let targetReady =
            projectType != .object ||
            (targetLocked && wellCoveredSectors >= 14)

        let surfaceReady =
            surfaceCoverageCells.isEmpty ||
            surfaceCoverageScore >= 0.55

        recommendedReady =
            coverage >= profile.targetCoverage &&
            confidenceReady &&
            depthReady &&
            trackingIsNormal &&
            targetReady &&
            surfaceReady

        updateMissingViewpointRecommendation(
            cameraPosition: cameraPosition,
            cameraYaw: yaw
        )

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

    private func updateSurfaceCoverage(
        meshPoints: [SIMD3<Float>],
        observedPoints: [SIMD3<Float>],
        confidence: Double?
    ) {
        let voxelSize: Float = projectType == .object ? 0.06 : 0.12

        func key(for point: SIMD3<Float>) -> PointKey {
            PointKey(
                x: Int((point.x / voxelSize).rounded()),
                y: Int((point.y / voxelSize).rounded()),
                z: Int((point.z / voxelSize).rounded())
            )
        }

        for point in meshPoints.prefix(1_200) {
            let pointKey = key(for: point)

            if surfaceCoverageStates[pointKey] == nil {
                surfaceCoverageStates[pointKey] = SurfaceCoverageState(
                    position: point,
                    observations: 0,
                    confidenceTotal: 0
                )
            }
        }

        let frameConfidence = confidence ?? 0.5

        for point in observedPoints {
            let pointKey = key(for: point)

            if var state = surfaceCoverageStates[pointKey] {
                state.observations = min(state.observations + 1, 12)
                state.confidenceTotal += frameConfidence
                state.position = (state.position + point) * 0.5
                surfaceCoverageStates[pointKey] = state
            } else {
                surfaceCoverageStates[pointKey] = SurfaceCoverageState(
                    position: point,
                    observations: 1,
                    confidenceTotal: frameConfidence
                )
            }
        }

        if surfaceCoverageStates.count > 6_000 {
            let retained = surfaceCoverageStates
                .sorted { lhs, rhs in
                    lhs.value.coverage > rhs.value.coverage
                }
                .prefix(4_500)
            surfaceCoverageStates = Dictionary(
                uniqueKeysWithValues: retained.map {
                    ($0.key, $0.value)
                }
            )
        }

        refreshSurfaceCoveragePublishedState()
    }

    private func refreshSurfaceCoveragePublishedState() {
        guard !surfaceCoverageStates.isEmpty else {
            surfaceCoverageCells = []
            surfaceCoverageScore = 0
            return
        }

        let allStates = Array(surfaceCoverageStates)
        surfaceCoverageScore =
            allStates.reduce(0.0) { $0 + $1.value.coverage } /
            Double(allStates.count)

        let weakest = allStates
            .sorted {
                if $0.value.coverage == $1.value.coverage {
                    return $0.value.confidence < $1.value.confidence
                }
                return $0.value.coverage < $1.value.coverage
            }
            .prefix(240)

        let strongest = allStates
            .filter { $0.value.coverage >= 0.66 }
            .prefix(80)

        var selected: [PointKey: SurfaceCoverageState] = [:]
        for entry in weakest {
            selected[entry.key] = entry.value
        }
        for entry in strongest {
            selected[entry.key] = entry.value
        }

        surfaceCoverageCells = selected.map { key, state in
            SurfaceCoverageCell(
                id: key.id,
                position: state.position,
                coverage: state.coverage,
                confidence: state.confidence
            )
        }
    }

    private func updateMissingViewpointRecommendation(
        cameraPosition: SIMD3<Float>,
        cameraYaw: Float
    ) {
        if projectType == .object,
           let targetPosition,
           targetLocked,
           let weakestIndex = coverageSectors.enumerated().min(
                by: { $0.element < $1.element }
           )?.offset {
            let row = weakestIndex / 8
            let column = weakestIndex % 8
            let desiredAzimuth =
                -Double.pi + (Double(column) + 0.5) * (2 * Double.pi / 8)

            let cameraOffset = cameraPosition - targetPosition
            let cameraAzimuth = atan2(
                Double(cameraOffset.x),
                Double(cameraOffset.z)
            )

            let delta = normalizedAngle(desiredAzimuth - cameraAzimuth)
            let degrees = Int(abs(delta) * 180 / Double.pi)

            missingViewpointRecommendation = MissingViewpointRecommendation(
                directionKey: directionKey(for: delta),
                azimuthDegrees: max(degrees, 5),
                elevationKey: row == 0
                    ? "viewpoint.lower"
                    : (row == 2 ? "viewpoint.higher" : "viewpoint.level"),
                coverage: coverageSectors[weakestIndex]
            )
            return
        }

        guard let missingCell = surfaceCoverageCells
            .filter({ $0.coverage < 0.66 })
            .min(by: {
                simd_distance($0.position, cameraPosition) <
                simd_distance($1.position, cameraPosition)
            }) else {
            missingViewpointRecommendation = nil
            return
        }

        let vector = missingCell.position - cameraPosition
        let desiredYaw = atan2(
            Double(vector.x),
            Double(-vector.z)
        )
        let delta = normalizedAngle(desiredYaw - Double(cameraYaw))
        let degrees = Int(abs(delta) * 180 / Double.pi)

        let verticalAngle = atan2(
            Double(vector.y),
            max(
                0.001,
                sqrt(
                    Double(vector.x * vector.x + vector.z * vector.z)
                )
            )
        )

        let elevationKey: String
        if verticalAngle > 0.20 {
            elevationKey = "viewpoint.higher"
        } else if verticalAngle < -0.20 {
            elevationKey = "viewpoint.lower"
        } else {
            elevationKey = "viewpoint.level"
        }

        missingViewpointRecommendation = MissingViewpointRecommendation(
            directionKey: directionKey(for: delta),
            azimuthDegrees: max(degrees, 5),
            elevationKey: elevationKey,
            coverage: missingCell.coverage
        )
    }

    private func directionKey(for delta: Double) -> String {
        if abs(delta) < 0.18 {
            return "viewpoint.forward"
        }
        return delta > 0
            ? "viewpoint.right"
            : "viewpoint.left"
    }

    private func normalizedAngle(_ angle: Double) -> Double {
        var value = angle
        while value > Double.pi { value -= 2 * Double.pi }
        while value < -Double.pi { value += 2 * Double.pi }
        return value
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

        if captureStage == .appearance {
            let blurRisk =
                exposureDurationSeconds > (1.0 / 30.0) &&
                motionSpeed > 0.12

            if blurRisk {
                return .holdSteady
            }

            if abs(exposureOffset) > 1.5 {
                return .improveLighting
            }
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

        if projectType == .object, !targetLocked {
            return .lockTarget
        }

        if featurePointCount < 45 {
            return .addVisualDetail
        }

        if projectType == .object, targetLocked {
            let covered = coverageSectors.filter { $0 >= 0.66 }.count
            if covered < 14 {
                return .fillCoverage
            }
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
            targetLocked: targetLocked,
            measurementCount: measurements.count,
            surfaceCoverageScore: surfaceCoverageScore,
            surfaceCellCount: surfaceCoverageCells.count
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
