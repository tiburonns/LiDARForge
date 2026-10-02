import Foundation

enum SensorViewMode: String, CaseIterable, Identifiable {
    case camera
    case cameraPoints
    case mesh
    case depth
    case confidence
    case raw

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .camera: return "sensor.camera"
        case .cameraPoints: return "sensor.cameraPoints"
        case .mesh: return "sensor.mesh"
        case .depth: return "sensor.depth"
        case .confidence: return "sensor.confidence"
        case .raw: return "sensor.raw"
        }
    }

    var symbol: String {
        switch self {
        case .camera: return "camera"
        case .cameraPoints: return "dot.scope"
        case .mesh: return "triangle"
        case .depth: return "square.3.layers.3d"
        case .confidence: return "checkmark.shield"
        case .raw: return "waveform.path.ecg.rectangle"
        }
    }
}
