import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    @State private var feedbackCategory = "feedback.suggestion"
    @State private var feedbackMessage = ""

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

            Section("customize.title") {
                NavigationLink {
                    ToolCustomizationView()
                } label: {
                    Label("customize.open", systemImage: "slider.horizontal.3")
                }

                Text("customize.summary")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("settings.about") {
                LabeledContent("settings.version", value: "0.2.0")
                LabeledContent(
                    "settings.processing",
                    value: String(localized: "settings.localFirst")
                )
            }

            Section("feedback.title") {
                Picker("feedback.category", selection: $feedbackCategory) {
                    ForEach(["feedback.bug", "feedback.comment", "feedback.suggestion", "feedback.other"], id: \.self) {
                        Text(LocalizedStringKey($0))
                    }
                }
                TextField("feedback.message", text: $feedbackMessage, axis: .vertical)
                    .lineLimit(4...8)
                Button("feedback.send", action: sendFeedback)
                    .disabled(feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("feedback.emailDraft")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("settings.title")
    }

    private func sendFeedback() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "tiburonns@icloud.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "[LiDARForge] [\(String(localized: String.LocalizationValue(feedbackCategory)))]"),
            URLQueryItem(name: "body", value: "\(feedbackMessage)\n\nLiDARForge \(version) (\(build))")
        ]
        if let url = components.url { openURL(url) }
    }
}

private struct ToolCustomizationView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section {
                ForEach(appState.captureTools) { tool in
                    ToolPreferenceRow(tool: tool)
                }
                .onMove { source, destination in
                    appState.moveTools(
                        in: \WorkspaceTool.isCaptureFunction,
                        from: source,
                        to: destination
                    )
                }
            } header: {
                Text("customize.captureFunctions")
            } footer: {
                Text("customize.captureFunctions.footer")
            }

            Section {
                ForEach(appState.sensorTools) { tool in
                    ToolPreferenceRow(tool: tool)
                }
                .onMove { source, destination in
                    appState.moveTools(
                        in: \WorkspaceTool.isSensorTool,
                        from: source,
                        to: destination
                    )
                }
            } header: {
                Text("customize.sensorTools")
            } footer: {
                Text("customize.sensorTools.footer")
            }

            Section {
                Button("customize.reset", role: .destructive) {
                    appState.resetToolLayout()
                }
            }
        }
        .navigationTitle("customize.title")
        .toolbar {
            EditButton()
        }
    }
}

private struct ToolPreferenceRow: View {
    @EnvironmentObject private var appState: AppState
    let tool: WorkspaceTool

    var body: some View {
        Toggle(
            isOn: Binding(
                get: { appState.isEnabled(tool) },
                set: { appState.setEnabled($0, for: tool) }
            )
        ) {
            HStack(spacing: 12) {
                Image(systemName: tool.symbol)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(tool.titleKey))
                    Text(LocalizedStringKey(tool.subtitleKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
