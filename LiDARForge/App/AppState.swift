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

@MainActor
final class AppState: ObservableObject {
    private static let languageKey = "LiDARForge.language"
    private static let captureQualityKey = "LiDARForge.captureQuality"

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

    init() {
        let savedLanguage = UserDefaults.standard.string(forKey: Self.languageKey)
        language = AppLanguage(rawValue: savedLanguage ?? "") ?? .system

        let savedQuality = UserDefaults.standard.string(
            forKey: Self.captureQualityKey
        )
        captureQuality = CaptureQualityMode(
            rawValue: savedQuality ?? ""
        ) ?? .balanced
    }

    var resolvedLocale: Locale {
        language.locale ?? .autoupdatingCurrent
    }
}
