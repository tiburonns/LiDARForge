import SwiftUI
import UIKit

struct SensorToolView: View {
    let titleKey: String
    let initialMode: SensorViewMode
    let nightVision: Bool

    @StateObject private var controller = LiDARSessionController()
    @State private var viewMode: SensorViewMode
    @State private var isRunning = true

    init(titleKey: String, initialMode: SensorViewMode, nightVision: Bool) {
        self.titleKey = titleKey
        self.initialMode = initialMode
        self.nightVision = nightVision
        _viewMode = State(initialValue: initialMode)
    }

    var body: some View {
        ZStack {
            ARScannerView(
                controller: controller,
                viewMode: viewMode,
                isRunning: isRunning
            )
            .ignoresSafeArea()

            if (viewMode == .depth || nightVision), let image = controller.depthPreview {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .background(.black)
            } else if viewMode == .confidence, let image = controller.confidencePreview {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .background(.black)
            }

            VStack {
                Spacer()

                VStack(spacing: 10) {
                    HStack {
                        metric("metric.tracking", controller.trackingDescription)
                        metric("metric.points", "\(controller.featurePointCount)")
                        metric("metric.mesh", "\(controller.meshAnchorCount)")
                    }

                    if controller.depthResolution != .zero {
                        Text(
                            "\(Int(controller.depthResolution.width)) × \(Int(controller.depthResolution.height)) depth"
                        )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }

                    Picker("sensor.mode", selection: $viewMode) {
                        ForEach(SensorViewMode.allCases) { mode in
                            Text(LocalizedStringKey(mode.titleKey)).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
            .padding()
        }
        .navigationTitle(LocalizedStringKey(titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            isRunning = false
        }
    }

    private func metric(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack {
            Text(value)
                .font(.caption.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
