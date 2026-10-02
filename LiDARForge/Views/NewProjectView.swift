import SwiftUI

struct NewProjectView: View {
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ProjectType.allCases) { type in
                    NavigationLink {
                        destination(for: type)
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: type.symbol)
                                .font(.system(size: 30, weight: .semibold))

                            Text(LocalizedStringKey(type.titleKey))
                                .font(.headline)

                            Text(LocalizedStringKey(type.subtitleKey))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 135, alignment: .topLeading)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("home.newProject")
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
