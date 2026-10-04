import SwiftUI
import UIKit

struct SensorToolView: View {
    let titleKey: String
    let tool: WorkspaceTool
    let mode: SensorViewMode
    var nightVision: Bool = false

    @EnvironmentObject private var appState: AppState

    @StateObject private var controller = LiDARSessionController()
    @State private var isRunning = true
    @State private var showDetails = false

    var body: some View {
        ZStack {
            ARScannerView(
                controller: controller,
                viewMode: mode,
                isRunning: isRunning,
                captureQuality: appState.captureQuality,
                captureWorkspace: false
            )
            .ignoresSafeArea()

            previewOverlay

            VStack(spacing: 12) {
                toolHeader

                Spacer()

                if showDetails {
                    detailsCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.snappy) {
                            showDetails.toggle()
                        }
                    } label: {
                        Label(
                            showDetails
                                ? "tools.hideDetails"
                                : "tools.showDetails",
                            systemImage: showDetails
                                ? "chevron.down"
                                : "info.circle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        isRunning.toggle()
                    } label: {
                        Image(
                            systemName: isRunning
                                ? "pause.fill"
                                : "play.fill"
                        )
                        .frame(width: 42)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(10)
                .background(
                    .ultraThinMaterial,
                    in: Capsule()
                )
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            isRunning = false
        }
    }

    @ViewBuilder
    private var previewOverlay: some View {
        if mode == .depth,
           let image = controller.depthPreview {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .background(.black)
                .colorMultiply(nightVision ? .green : .white)
        } else if mode == .confidence,
                  let image = controller.confidencePreview {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .background(.black)
        }
    }

    private var toolHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: tool.symbol)
                .font(.headline)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(titleKey))
                    .font(.headline)

                Text(
                    isRunning
                        ? "tools.live"
                        : "tools.paused"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(isRunning ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
        }
        .padding(12)
        .background(
            .ultraThinMaterial,
            in: Capsule()
        )
    }

    private var detailsCard: some View {
        VStack(spacing: 10) {
            HStack {
                metric(
                    "metric.tracking",
                    controller.trackingDescription
                )
                metric(
                    "metric.points",
                    controller.featurePointCount.formatted()
                )
                metric(
                    "metric.mesh",
                    controller.meshAnchorCount.formatted()
                )
            }

            if controller.depthResolution != .zero {
                Divider()

                HStack {
                    Label(
                        "tools.depthResolution",
                        systemImage: "square.3.layers.3d"
                    )
                    .font(.caption)

                    Spacer()

                    Text(
                        "\(Int(controller.depthResolution.width)) × \(Int(controller.depthResolution.height))"
                    )
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    private func metric(
        _ title: LocalizedStringKey,
        _ value: String
    ) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
