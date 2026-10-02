import Foundation

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
