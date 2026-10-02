import SwiftUI

struct ProjectsView: View {
    @State private var projects: [ScanProject] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if projects.isEmpty {
                ContentUnavailableView(
                    "projects.empty.title",
                    systemImage: "cube.transparent",
                    description: Text("projects.empty.subtitle")
                )
            } else {
                List {
                    ForEach(projects) { project in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(
                                    LocalizedStringKey(project.type.titleKey),
                                    systemImage: project.type.symbol
                                )
                                .font(.headline)

                                Spacer()

                                Text(project.updatedAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text(LocalizedStringKey(project.stage.titleKey))
                                Spacer()
                                Text(project.metrics.coverage, format: .percent.precision(.fractionLength(0)))
                            }
                            .font(.subheadline)

                            ProgressView(value: project.metrics.coverage)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("projects.title")
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
    }

    private func reload() async {
        let stored = await ProjectStore.shared.listProjects()
        await MainActor.run {
            projects = stored
            isLoading = false
        }
    }

    private func delete(at offsets: IndexSet) {
        let ids = offsets.map { projects[$0].id }
        projects.remove(atOffsets: offsets)

        Task {
            for id in ids {
                try? await ProjectStore.shared.deleteProject(id: id)
            }
        }
    }
}
