import SwiftUI

struct NewProjectView: View {
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("newProject.title")
                        .font(.title2.bold())

                    Text("newProject.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ProjectType.allCases) { type in
                        NavigationLink {
                            destination(for: type)
                        } label: {
                            projectCard(type)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("home.newProject")
    }

    private func projectCard(_ type: ProjectType) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: type.symbol)
                    .font(.system(size: 28, weight: .semibold))

                Spacer()

                Text(LocalizedStringKey(type.engineKey))
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
            }

            Text(LocalizedStringKey(type.titleKey))
                .font(.headline)

            Text(LocalizedStringKey(type.subtitleKey))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)

            Divider()

            HStack(spacing: 5) {
                Image(systemName: "1.circle.fill")
                Text("stage.structure")
                Image(systemName: "chevron.right")
                Image(systemName: "2.circle.fill")
                Text("stage.detail")
                Image(systemName: "chevron.right")
                Image(systemName: "3.circle.fill")
                Text("stage.appearance")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 178,
            alignment: .topLeading
        )
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    @ViewBuilder
    private func destination(for type: ProjectType) -> some View {
        if type == .interior {
            RoomPlanProjectView(projectType: type)
        } else if type == .building {
            BuildingRoomPlanProjectView()
        } else {
            ScannerView(projectType: type)
        }
    }
}
