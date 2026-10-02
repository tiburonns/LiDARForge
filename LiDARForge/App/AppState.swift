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

@MainActor
final class AppState: ObservableObject {
    private static let languageKey = "LiDARForge.language"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.languageKey)
        language = AppLanguage(rawValue: saved ?? "") ?? .system
    }

    var resolvedLocale: Locale {
        language.locale ?? .autoupdatingCurrent
    }
}
