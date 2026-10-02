import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case spanish

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system: return "language.system"
        case .english: return "language.english"
        case .spanish: return "language.spanish"
        }
    }

    var locale: Locale? {
        switch self {
        case .system: return nil
        case .english: return Locale(identifier: "en")
        case .spanish: return Locale(identifier: "es")
        }
    }
}

enum CaptureQualityMode: String, CaseIterable, Identifiable {
    case fast
    case balanced
    case maximum

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .fast: return "quality.fast"
        case .balanced: return "quality.balanced"
        case .maximum: return "quality.maximum"
        }
    }

    var subtitleKey: String {
        switch self {
        case .fast: return "quality.fast.subtitle"
        case .balanced: return "quality.balanced.subtitle"
        case .maximum: return "quality.maximum.subtitle"
        }
    }

    var denseSampleInterval: TimeInterval {
        switch self {
        case .fast: return 0.80
        case .balanced: return 0.50
        case .maximum: return 0.25
        }
    }

    var depthSampleStride: Int {
        switch self {
        case .fast: return 9
        case .balanced: return 6
        case .maximum: return 4
        }
    }

    var previewInterval: TimeInterval {
        switch self {
        case .fast: return 0.35
        case .balanced: return 0.20
        case .maximum: return 0.12
        }
    }
}

enum WorkspaceTool: String, CaseIterable, Identifiable, Codable, Hashable {
    case measurements
    case scanHealth
    case coverageHeatmap
    case pointCloudExport
    case sourceArchive
    case nightVision
    case depthView
    case confidenceView
    case featurePoints
    case meshView
    case rawInspector

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .measurements: return "customize.measurements"
        case .scanHealth: return "customize.scanHealth"
        case .coverageHeatmap: return "customize.coverageHeatmap"
        case .pointCloudExport: return "customize.pointCloudExport"
        case .sourceArchive: return "customize.sourceArchive"
        case .nightVision: return "tool.nightVision"
        case .depthView: return "tool.depth"
        case .confidenceView: return "tool.confidence"
        case .featurePoints: return "tool.points"
        case .meshView: return "tool.mesh"
        case .rawInspector: return "tool.raw"
        }
    }

    var subtitleKey: String {
        switch self {
        case .measurements: return "customize.measurements.subtitle"
        case .scanHealth: return "customize.scanHealth.subtitle"
        case .coverageHeatmap: return "customize.coverageHeatmap.subtitle"
        case .pointCloudExport: return "customize.pointCloudExport.subtitle"
        case .sourceArchive: return "customize.sourceArchive.subtitle"
        case .nightVision: return "customize.nightVision.subtitle"
        case .depthView: return "customize.depth.subtitle"
        case .confidenceView: return "customize.confidence.subtitle"
        case .featurePoints: return "customize.points.subtitle"
        case .meshView: return "customize.mesh.subtitle"
        case .rawInspector: return "customize.raw.subtitle"
        }
    }

    var symbol: String {
        switch self {
        case .measurements: return "ruler"
        case .scanHealth: return "waveform.path.ecg"
        case .coverageHeatmap: return "square.grid.3x3.fill"
        case .pointCloudExport: return "point.3.connected.trianglepath.dotted"
        case .sourceArchive: return "archivebox"
        case .nightVision: return "moon.stars"
        case .depthView: return "square.3.layers.3d"
        case .confidenceView: return "checkmark.shield"
        case .featurePoints: return "dot.scope"
        case .meshView: return "triangle"
        case .rawInspector: return "waveform.path.ecg.rectangle"
        }
    }

    var isCaptureFunction: Bool {
        switch self {
        case .measurements, .scanHealth, .coverageHeatmap,
             .pointCloudExport, .sourceArchive:
            return true
        default:
            return false
        }
    }

    var isSensorTool: Bool {
        !isCaptureFunction
    }

    static let defaultOrder: [WorkspaceTool] = [
        .measurements,
        .scanHealth,
        .coverageHeatmap,
        .pointCloudExport,
        .sourceArchive,
        .nightVision,
        .depthView,
        .confidenceView,
        .featurePoints,
        .meshView,
        .rawInspector
    ]
}

@MainActor
final class AppState: ObservableObject {
    private static let languageKey = "LiDARForge.language"
    private static let captureQualityKey = "LiDARForge.captureQuality"
    private static let enabledToolsKey = "LiDARForge.enabledTools"
    private static let toolOrderKey = "LiDARForge.toolOrder"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
        }
    }

    @Published var captureQuality: CaptureQualityMode {
        didSet {
            UserDefaults.standard.set(
                captureQuality.rawValue,
                forKey: Self.captureQualityKey
            )
        }
    }

    @Published private(set) var enabledTools: Set<WorkspaceTool> {
        didSet {
            let values = enabledTools.map(\.rawValue).sorted()
            UserDefaults.standard.set(values, forKey: Self.enabledToolsKey)
        }
    }

    @Published private(set) var toolOrder: [WorkspaceTool] {
        didSet {
            UserDefaults.standard.set(
                toolOrder.map(\.rawValue),
                forKey: Self.toolOrderKey
            )
        }
    }

    init() {
        let savedLanguage = UserDefaults.standard.string(forKey: Self.languageKey)
        language = AppLanguage(rawValue: savedLanguage ?? "") ?? .system

        let savedQuality = UserDefaults.standard.string(
            forKey: Self.captureQualityKey
        )
        captureQuality = CaptureQualityMode(
            rawValue: savedQuality ?? ""
        ) ?? .balanced

        if let saved = UserDefaults.standard.stringArray(
            forKey: Self.enabledToolsKey
        ) {
            enabledTools = Set(saved.compactMap(WorkspaceTool.init(rawValue:)))
        } else {
            enabledTools = Set(WorkspaceTool.defaultOrder)
        }

        if let saved = UserDefaults.standard.stringArray(
            forKey: Self.toolOrderKey
        ) {
            let restored = saved.compactMap(WorkspaceTool.init(rawValue:))
            let missing = WorkspaceTool.defaultOrder.filter {
                !restored.contains($0)
            }
            toolOrder = restored + missing
        } else {
            toolOrder = WorkspaceTool.defaultOrder
        }
    }

    var resolvedLocale: Locale {
        language.locale ?? .autoupdatingCurrent
    }

    var captureTools: [WorkspaceTool] {
        toolOrder.filter { $0.isCaptureFunction }
    }

    var sensorTools: [WorkspaceTool] {
        toolOrder.filter { $0.isSensorTool }
    }

    func isEnabled(_ tool: WorkspaceTool) -> Bool {
        enabledTools.contains(tool)
    }

    func setEnabled(_ enabled: Bool, for tool: WorkspaceTool) {
        if enabled {
            enabledTools.insert(tool)
        } else {
            enabledTools.remove(tool)
        }
    }

    func moveTools(
        in category: KeyPath<WorkspaceTool, Bool>,
        from source: IndexSet,
        to destination: Int
    ) {
        let categoryTools = toolOrder.filter { $0[keyPath: category] }
        var reordered = categoryTools
        reordered.move(fromOffsets: source, toOffset: destination)

        var iterator = reordered.makeIterator()
        toolOrder = toolOrder.map { tool in
            if tool[keyPath: category] {
                return iterator.next() ?? tool
            }
            return tool
        }
    }

    func resetToolLayout() {
        enabledTools = Set(WorkspaceTool.defaultOrder)
        toolOrder = WorkspaceTool.defaultOrder
    }
}
