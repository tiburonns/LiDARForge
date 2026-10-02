import ARKit
import RealityKit
import SwiftUI
import UIKit

struct ARScannerView: UIViewRepresentable {
    @ObservedObject var controller: LiDARSessionController
    var viewMode: SensorViewMode
    var isRunning: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        context.coordinator.attach(to: view)
        context.coordinator.setViewMode(viewMode, on: view)
        context.coordinator.setRunning(isRunning, on: view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.setViewMode(viewMode, on: uiView)
        context.coordinator.setRunning(isRunning, on: uiView)
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
        uiView.session.delegate = nil
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        private let controller: LiDARSessionController
        private var running = false
        private var lastMetricsTimestamp: TimeInterval = 0
        private var lastPreviewTimestamp: TimeInterval = 0

        init(controller: LiDARSessionController) {
            self.controller = controller
        }

        func attach(to view: ARView) {
            view.session.delegate = self
        }

        func setRunning(_ shouldRun: Bool, on view: ARView) {
            guard shouldRun != running else { return }
            running = shouldRun

            if shouldRun {
                let configuration = ARWorldTrackingConfiguration()
                configuration.worldAlignment = .gravity
                configuration.planeDetection = [.horizontal, .vertical]
                configuration.environmentTexturing = .automatic

                if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                    configuration.sceneReconstruction = .meshWithClassification
                } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                    configuration.sceneReconstruction = .mesh
                }

                if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                    configuration.frameSemantics.insert(.sceneDepth)
                }

                if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
                    configuration.frameSemantics.insert(.smoothedSceneDepth)
                }

                view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

                Task { @MainActor [weak controller] in
                    controller?.reset()
                }
            } else {
                view.session.pause()
            }
        }

        func setViewMode(_ mode: SensorViewMode, on view: ARView) {
            var options: ARView.DebugOptions = []

            switch mode {
            case .camera:
                break
            case .cameraPoints:
                options.insert(.showFeaturePoints)
            case .mesh:
                options.insert(.showSceneUnderstanding)
            case .depth, .confidence:
                break
            case .raw:
                options.insert(.showWorldOrigin)
                options.insert(.showFeaturePoints)
            }

            view.debugOptions = options
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard frame.timestamp - lastMetricsTimestamp >= 0.10 else { return }
            lastMetricsTimestamp = frame.timestamp

            let depth = frame.smoothedSceneDepth ?? frame.sceneDepth
            let resolution: CGSize
            if let depth {
                resolution = CGSize(
                    width: CVPixelBufferGetWidth(depth.depthMap),
                    height: CVPixelBufferGetHeight(depth.depthMap)
                )
            } else {
                resolution = .zero
            }

            let confidence = LiDARFrameProcessor.confidenceScore(from: depth?.confidenceMap)

            var depthPreview: UIImage?
            var confidencePreview: UIImage?

            if frame.timestamp - lastPreviewTimestamp >= 0.20, let depth {
                lastPreviewTimestamp = frame.timestamp
                depthPreview = LiDARFrameProcessor.depthImage(from: depth.depthMap)
                confidencePreview = LiDARFrameProcessor.confidenceImage(from: depth.confidenceMap)
            }

            let transform = frame.camera.transform
            let position = SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )

            let tracking = LiDARFrameProcessor.trackingDescription(frame.camera.trackingState)
            let points = frame.rawFeaturePoints?.points.count ?? 0
            let meshes = frame.anchors.reduce(into: 0) { count, anchor in
                if anchor is ARMeshAnchor { count += 1 }
            }

            let yaw = frame.camera.eulerAngles.y
            let pitch = frame.camera.eulerAngles.x

            Task { @MainActor [weak controller] in
                controller?.update(
                    featurePoints: points,
                    meshAnchors: meshes,
                    tracking: tracking,
                    yaw: yaw,
                    pitch: pitch,
                    cameraPosition: position,
                    depthResolution: resolution,
                    confidence: confidence,
                    depthPreview: depthPreview,
                    confidencePreview: confidencePreview
                )
            }
        }
    }
}
