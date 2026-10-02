import SwiftUI

struct ToolsView: View {
    private let tools: [(String, String, SensorViewMode, Bool)] = [
        ("tool.nightVision", "moon.stars", .depth, true),
        ("tool.depth", "square.3.layers.3d", .depth, false),
        ("tool.confidence", "checkmark.shield", .confidence, false),
        ("tool.points", "dot.scope", .cameraPoints, false),
        ("tool.mesh", "triangle", .mesh, false),
        ("tool.raw", "waveform.path.ecg.rectangle", .raw, false)
    ]

    var body: some View {
        List {
            ForEach(Array(tools.enumerated()), id: \.offset) { _, tool in
                NavigationLink {
                    SensorToolView(
                        titleKey: tool.0,
                        initialMode: tool.2,
                        nightVision: tool.3
                    )
                } label: {
                    Label(LocalizedStringKey(tool.0), systemImage: tool.1)
                }
            }
        }
        .navigationTitle("home.sensorTools")
    }
}
