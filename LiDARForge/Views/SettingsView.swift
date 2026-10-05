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

            Section("support.title") {
                NavigationLink {
                    LiDARForgeFeedbackView()
                } label: {
                    Label("support.feedback", systemImage: "bubble.left.and.bubble.right")
                }

                Link(
                    destination: URL(string: "https://github.com/tiburonns/LiDARForge/issues")!
                ) {
                    Label("support.issues", systemImage: "exclamationmark.bubble")
                }

                Text("support.privateRepo")
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
        }
        .navigationTitle("settings.title")
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


private struct LiDARForgeFeedbackView: View {
    private enum Category: String, CaseIterable, Identifiable {
        case question, suggestion, bug, feedback
        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .question: "feedback.category.question"
            case .suggestion: "feedback.category.suggestion"
            case .bug: "feedback.category.bug"
            case .feedback: "feedback.category.feedback"
            }
        }

        var issuePrefix: String {
            switch self {
            case .question: "Question"
            case .suggestion: "Suggestion"
            case .bug: "Bug"
            case .feedback: "Feedback"
            }
        }
    }

    @Environment(\.openURL) private var openURL
    @State private var category = Category.question
    @State private var message = ""

    var body: some View {
        Form {
            Section("feedback.type") {
                Picker("feedback.category", selection: $category) {
                    ForEach(Category.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
            }

            Section("feedback.message") {
                TextEditor(text: $message)
                    .frame(minHeight: 160)

                Text("feedback.privacy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    submit()
                } label: {
                    Label("feedback.send", systemImage: "paperplane.fill")
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text("feedback.review")
            }
        }
        .navigationTitle("feedback.title")
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    private func submit() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = "/tiburonns/LiDARForge/issues/new"
        components.queryItems = [
            URLQueryItem(name: "title", value: "[\(category.issuePrefix)] "),
            URLQueryItem(
                name: "body",
                value: """
                \(message)

                ---
                App: LiDARForge
                Version: \(appVersion)
                """
            )
        ]

        if let url = components.url {
            openURL(url)
        }
    }
}
