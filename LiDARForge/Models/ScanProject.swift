import Foundation

struct ScanMetricsSnapshot: Codable {
    let coverage: Double
    let confidence: Double?
    let featurePointCount: Int
    let meshAnchorCount: Int
    let trackingDescription: String
    let depthWidth: Int
    let depthHeight: Int

    // Optional fields keep snapshots created by earlier builds decodable.
    let depthValidRatio: Double?
    let centerDistanceMeters: Double?
    let densePointCount: Int?
    let thermalDescription: String?
    let targetLocked: Bool?

    init(
        coverage: Double,
        confidence: Double?,
        featurePointCount: Int,
        meshAnchorCount: Int,
        trackingDescription: String,
        depthWidth: Int,
        depthHeight: Int,
        depthValidRatio: Double? = nil,
        centerDistanceMeters: Double? = nil,
        densePointCount: Int? = nil,
        thermalDescription: String? = nil,
        targetLocked: Bool? = nil
    ) {
        self.coverage = coverage
        self.confidence = confidence
        self.featurePointCount = featurePointCount
        self.meshAnchorCount = meshAnchorCount
        self.trackingDescription = trackingDescription
        self.depthWidth = depthWidth
        self.depthHeight = depthHeight
        self.depthValidRatio = depthValidRatio
        self.centerDistanceMeters = centerDistanceMeters
        self.densePointCount = densePointCount
        self.thermalDescription = thermalDescription
        self.targetLocked = targetLocked
    }
}

struct ScanProject: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var name: String
    var type: ProjectType
    var stage: CaptureStage
    var metrics: ScanMetricsSnapshot
}
