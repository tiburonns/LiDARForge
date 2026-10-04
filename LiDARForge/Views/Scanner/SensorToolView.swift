import SwiftUI
import UIKit

struct SensorToolView: View {
    let titleKey: String
    let tool: WorkspaceTool
    let mode: SensorViewMode
    var nightVision: Bool = false

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var controller = LiDARSessionController()
    @State private var isRunning = true
    @State private var showDetails = false

    var body: some View {
        GeometryReader { geometry in
            let viewport = geometry.size
            let hudWidth = min(
                max(viewport.width - 32, 1),
                560
            )
            ZStack {
                ARScannerView(
                    controller: controller,
                    viewMode: mode,
                    isRunning: isRunning,
                    captureQuality: appState.captureQuality,
                    captureWorkspace: false
                )
                .frame(
                    width: viewport.width,
                    height: viewport.height
                )
                .clipped()

                previewOverlay(size: viewport)
            }
            .frame(
                width: viewport.width,
                height: viewport.height
            )
            .clipped()
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                HStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 48, height: 48)
                            .background(
                                .ultraThinMaterial,
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)

                    toolHeader
                        .frame(maxWidth: hudWidth)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    if showDetails {
                        detailsCard
                            .frame(width: hudWidth)
                            .transition(
                                .move(edge: .bottom)
                                .combined(with: .opacity)
                            )
                    }

                    controls
                        .frame(width: hudWidth)
                }
                .padding(.bottom, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            isRunning = false
        }
    }

    @ViewBuilder
    private func previewOverlay(size: CGSize) -> some View {
        if mode == .depth,
           let image = controller.depthPreview {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(
                    width: size.width,
                    height: size.height
                )
                .clipped()
                .background(.black)
                .colorMultiply(nightVision ? .green : .white)
                .allowsHitTesting(false)
        } else if mode == .confidence,
                  let image = controller.confidencePreview {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(
                    width: size.width,
                    height: size.height
                )
                .clipped()
                .background(.black)
                .allowsHitTesting(false)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.snappy) {
                    showDetails.toggle()
                }
            } label: {
                Label {
                    Text(
                        LocalizedStringKey(
                            showDetails
                                ? "tools.hideDetails"
                                : "tools.showDetails"
                        )
                    )
                } icon: {
                    Image(
                        systemName: showDetails
                            ? "chevron.down"
                            : "info.circle"
                    )
                }
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
                .frame(width: 44, height: 20)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(10)
        .background(
            .ultraThinMaterial,
            in: Capsule()
        )
    }

    private var toolHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: tool.symbol)
                .font(.headline)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(titleKey))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(
                    LocalizedStringKey(
                        isRunning
                            ? "tools.live"
                            : "tools.paused"
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

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
        ScrollView {
            VStack(spacing: 10) {
                if tool == .rawInspector {
                    rawInspectorDetails
                } else {
                    standardDetails
                }
            }
            .padding()
        }
        .frame(maxHeight: 250)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    private var standardDetails: some View {
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
    }

    private var rawInspectorDetails: some View {
        VStack(spacing: 9) {
            Text("raw.explanation")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            rawRow(
                "raw.position",
                String(
                    format: "X %.3f  Y %.3f  Z %.3f m",
                    controller.cameraPosition.x,
                    controller.cameraPosition.y,
                    controller.cameraPosition.z
                )
            )

            rawRow(
                "raw.orientation",
                String(
                    format: "Yaw %.1f°  Pitch %.1f°",
                    Double(controller.cameraYaw) * 180.0 / .pi,
                    Double(controller.cameraPitch) * 180.0 / .pi
                )
            )

            rawRow(
                "raw.timestamp",
                controller.frameTimestamp.formatted(
                    .number.precision(.fractionLength(3))
                ) + " s"
            )

            rawRow(
                "metric.tracking",
                controller.trackingDescription
            )

            rawRow(
                "metric.points",
                controller.featurePointCount.formatted()
            )

            rawRow(
                "metric.mesh",
                controller.meshAnchorCount.formatted()
            )

            rawRow(
                "raw.validDepth",
                controller.depthValidRatio.formatted(
                    .percent.precision(.fractionLength(0))
                )
            )

            rawRow(
                "metric.confidence",
                controller.confidence?.formatted(
                    .percent.precision(.fractionLength(0))
                ) ?? "—"
            )

            rawRow(
                "raw.exposure",
                (controller.exposureDurationSeconds * 1000)
                    .formatted(
                        .number.precision(.fractionLength(1))
                    ) + " ms"
            )
        }
    }

    private func rawRow(
        _ title: LocalizedStringKey,
        _ value: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption.monospaced())
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
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
