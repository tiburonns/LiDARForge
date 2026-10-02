import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("settings.language") {
                Picker("settings.language", selection: $appState.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.titleKey))
                            .tag(language)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("settings.about") {
                LabeledContent("settings.version", value: "0.1.0")
                LabeledContent("settings.processing", value: String(localized: "settings.localFirst"))
            }
        }
        .navigationTitle("settings.title")
    }
}
