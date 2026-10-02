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

            Section("quality.title") {
                Picker("quality.title", selection: $appState.captureQuality) {
                    ForEach(CaptureQualityMode.allCases) { mode in
                        VStack(alignment: .leading) {
                            Text(LocalizedStringKey(mode.titleKey))
                            Text(LocalizedStringKey(mode.subtitleKey))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("settings.about") {
                LabeledContent("settings.version", value: "0.2.0")
                LabeledContent("settings.processing", value: String(localized: "settings.localFirst"))
            }
        }
        .navigationTitle("settings.title")
    }
}
