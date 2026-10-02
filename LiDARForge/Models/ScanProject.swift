import Foundation

struct ScanMetricsSnapshot: Codable {
    let coverage: Double
    let confidence: Double?
    let featurePointCount: Int
    let meshAnchorCount: Int
    let trackingDescription: String
    let depthWidth: Int
    let depthHeight: Int
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
