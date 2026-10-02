import Foundation

struct CaptureProfile {
    let cellSize: Float
    let targetCoverage: Double
    let maxSpeed: Double
    let minDistance: Double
    let maxDistance: Double
    let orientationTarget: Double
    let movementTarget: Double
    let geometryTarget: Double

    static let sensor = CaptureProfile(
        cellSize: 0.50,
        targetCoverage: 0.72,
        maxSpeed: 0.90,
        minDistance: 0.30,
        maxDistance: 4.50,
        orientationTarget: 18,
        movementTarget: 14,
        geometryTarget: 24
    )
}

enum ProjectType: String, CaseIterable, Identifiable, Codable {
    case object
    case interior
    case exterior
    case building
    case video

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .object: return "project.object"
        case .interior: return "project.interior"
        case .exterior: return "project.exterior"
        case .building: return "project.building"
        case .video: return "project.video"
        }
    }

    var subtitleKey: String {
        switch self {
        case .object: return "project.object.subtitle"
        case .interior: return "project.interior.subtitle"
        case .exterior: return "project.exterior.subtitle"
        case .building: return "project.building.subtitle"
        case .video: return "project.video.subtitle"
        }
    }

    var symbol: String {
        switch self {
        case .object: return "cube.transparent"
        case .interior: return "house"
        case .exterior: return "mountain.2"
        case .building: return "building.2"
        case .video: return "video"
        }
    }

    var captureProfile: CaptureProfile {
        switch self {
        case .object:
            return CaptureProfile(
                cellSize: 0.18,
                targetCoverage: 0.82,
                maxSpeed: 0.55,
                minDistance: 0.30,
                maxDistance: 1.60,
                orientationTarget: 24,
                movementTarget: 16,
                geometryTarget: 14
            )
        case .interior:
            return CaptureProfile(
                cellSize: 0.50,
                targetCoverage: 0.76,
                maxSpeed: 0.80,
                minDistance: 0.45,
                maxDistance: 4.50,
                orientationTarget: 18,
                movementTarget: 18,
                geometryTarget: 24
            )
        case .exterior:
            return CaptureProfile(
                cellSize: 0.90,
                targetCoverage: 0.70,
                maxSpeed: 1.00,
                minDistance: 0.50,
                maxDistance: 5.00,
                orientationTarget: 16,
                movementTarget: 20,
                geometryTarget: 28
            )
        case .building:
            return CaptureProfile(
                cellSize: 1.00,
                targetCoverage: 0.74,
                maxSpeed: 0.90,
                minDistance: 0.50,
                maxDistance: 5.00,
                orientationTarget: 18,
                movementTarget: 24,
                geometryTarget: 32
            )
        case .video:
            return CaptureProfile(
                cellSize: 0.40,
                targetCoverage: 0.60,
                maxSpeed: 0.75,
                minDistance: 0.40,
                maxDistance: 4.00,
                orientationTarget: 12,
                movementTarget: 10,
                geometryTarget: 12
            )
        }
    }
}

enum CaptureStage: String, CaseIterable, Identifiable, Codable {
    case structure
    case detail
    case appearance

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .structure: return "stage.structure"
        case .detail: return "stage.detail"
        case .appearance: return "stage.appearance"
        }
    }

    var instructionKey: String {
        switch self {
        case .structure: return "stage.structure.instruction"
        case .detail: return "stage.detail.instruction"
        case .appearance: return "stage.appearance.instruction"
        }
    }

    var next: CaptureStage? {
        switch self {
        case .structure: return .detail
        case .detail: return .appearance
        case .appearance: return nil
        }
    }
}
