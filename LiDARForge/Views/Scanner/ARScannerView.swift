import Foundation
import ARKit
import RealityKit
import SwiftUI
import UIKit

struct ARScannerView: UIViewRepresentable {
    @ObservedObject var controller: LiDARSessionController
    var viewMode: SensorViewMode
    var isRunning: Bool
    var allowsTargetLock: Bool = false
    var measurementMode: Bool = false
    var captureQuality: CaptureQualityMode = .balanced
    var rgbdRecorder: RGBDRecorder?
    var initialWorldMapData: Data?

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        context.coordinator.attach(to: view)
        context.coordinator.setAllowsTargetLock(allowsTargetLock)
        context.coordinator.setMeasurementMode(measurementMode)
        context.coordinator.setCaptureQuality(captureQuality)
        context.coordinator.setRGBDRecorder(rgbdRecorder)
        context.coordinator.setInitialWorldMapData(initialWorldMapData)
        context.coordinator.setViewMode(viewMode, on: view)
        context.coordinator.setRunning(isRunning, on: view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.setAllowsTargetLock(allowsTargetLock)
        context.coordinator.setMeasurementMode(measurementMode)
        context.coordinator.setCaptureQuality(captureQuality)
        context.coordinator.setRGBDRecorder(rgbdRecorder)
        context.coordinator.setInitialWorldMapData(initialWorldMapData)
        context.coordinator.setViewMode(viewMode, on: uiView)
        context.coordinator.setRunning(isRunning, on: uiView)
        context.coordinator.handleWorldMapSaveRequest(
            controller.worldMapSaveRequestID,
            on: uiView
        )
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
        uiView.session.delegate = nil
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        private let controller: LiDARSessionController
        private weak var arView: ARView?
        private var running = false
        private var hasStarted = false
        private var lastMetricsTimestamp: TimeInterval = 0
        private var lastPreviewTimestamp: TimeInterval = 0
        private var lastPointCloudTimestamp: TimeInterval = 0
        private var lastRGBDTimestamp: TimeInterval = 0
        private var allowsTargetLock = false
        private var measurementMode = false
        private var captureQuality: CaptureQualityMode = .balanced
        private weak var rgbdRecorder: RGBDRecorder?
        private var initialWorldMapData: Data?
        private var lastWorldMapSaveRequestID: UUID?

        init(controller: LiDARSessionController) {
            self.controller = controller
        }

        func attach(to view: ARView) {
            arView = view
            view.session.delegate = self

            let tap = UITapGestureRecognizer(
                target: self,
                action: #selector(handleTargetTap(_:))
            )
            tap.cancelsTouchesInView = false
            view.addGestureRecognizer(tap)
        }

        func setAllowsTargetLock(_ allowed: Bool) {
            allowsTargetLock = allowed
        }

        func setMeasurementMode(_ enabled: Bool) {
            measurementMode = enabled
            if !enabled {
                Task { @MainActor [weak controller] in
                    controller?.cancelMeasurementDraft()
                }
            }
        }

        func setCaptureQuality(_ quality: CaptureQualityMode) {
            captureQuality = quality
        }

        func setRGBDRecorder(_ recorder: RGBDRecorder?) {
            rgbdRecorder = recorder
        }

        func setInitialWorldMapData(_ data: Data?) {
            guard !hasStarted else { return }
            initialWorldMapData = data
        }

        func handleWorldMapSaveRequest(
            _ requestID: UUID?,
            on view: ARView
        ) {
            guard let requestID,
                  requestID != lastWorldMapSaveRequestID else {
                return
            }

            lastWorldMapSaveRequestID = requestID

            view.session.getCurrentWorldMap { [weak self] worldMap, error in
                guard let self else { return }

                if let error {
                    Task { @MainActor [weak controller] in
                        controller?.setSessionError(error.localizedDescription)
                    }
                    return
                }

                guard let worldMap else { return }

                do {
                    let data = try NSKeyedArchiver.archivedData(
                        withRootObject: worldMap,
                        requiringSecureCoding: true
                    )

                    Task { @MainActor [weak controller] in
                        controller?.receiveWorldMapData(data)
                    }
                } catch {
                    Task { @MainActor [weak controller] in
                        controller?.setSessionError(error.localizedDescription)
                    }
                }
            }
        }

        @objc
        private func handleTargetTap(_ gesture: UITapGestureRecognizer) {
            guard (allowsTargetLock || measurementMode),
                  gesture.state == .ended,
                  let view = arView else {
                return
            }

            let location = gesture.location(in: view)
            guard let result = view.raycast(
                from: location,
                allowing: .estimatedPlane,
                alignment: .any
            ).first else {
                return
            }

            let transform = result.worldTransform
            let target = SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )

            let cameraPosition: SIMD3<Float>?
            if let cameraTransform = view.session.currentFrame?.camera.transform {
                cameraPosition = SIMD3<Float>(
                    cameraTransform.columns.3.x,
                    cameraTransform.columns.3.y,
                    cameraTransform.columns.3.z
                )
            } else {
                cameraPosition = nil
            }

            if measurementMode {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()

                Task { @MainActor [weak controller] in
                    controller?.addMeasurementPoint(target)
                }
                return
            }

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            Task { @MainActor [weak controller] in
                controller?.lockTarget(
                    position: target,
                    cameraPosition: cameraPosition
                )
            }
        }

        func setRunning(_ shouldRun: Bool, on view: ARView) {
            guard shouldRun != running else { return }
            running = shouldRun

            if shouldRun {
                runSession(
                    on: view,
                    resetTracking: !hasStarted,
                    clearPointCloud: !hasStarted
                )
                hasStarted = true
            } else {
                view.session.pause()
            }
        }

        private func runSession(
            on view: ARView,
            resetTracking: Bool,
            clearPointCloud: Bool
        ) {
            let configuration = ARWorldTrackingConfiguration()
            configuration.worldAlignment = .gravity

            if resetTracking,
               let data = initialWorldMapData,
               let worldMap = try? NSKeyedUnarchiver.unarchivedObject(
                    ofClass: ARWorldMap.self,
                    from: data
               ) {
                configuration.initialWorldMap = worldMap
            }
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

            let options: ARSession.RunOptions = resetTracking
                ? [.resetTracking, .removeExistingAnchors]
                : []

            view.session.run(configuration, options: options)

            if resetTracking {
                Task { @MainActor [weak controller] in
                    controller?.reset(clearPointCloud: clearPointCloud)
                }
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
            let depthStatistics = LiDARFrameProcessor.depthStatistics(from: depth?.depthMap)

            if let rgbdRecorder,
               rgbdRecorder.isRecording,
               frame.timestamp - lastRGBDTimestamp >= max(
                   0.20,
                   captureQuality.denseSampleInterval
               ) {
                lastRGBDTimestamp = frame.timestamp
                rgbdRecorder.capture(
                    frame: frame,
                    depth: depth
                )
            }

            var depthPreview: UIImage?
            var confidencePreview: UIImage?

            if frame.timestamp - lastPreviewTimestamp >= captureQuality.previewInterval,
               let depth {
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
            let trackingNormal = LiDARFrameProcessor.isTrackingNormal(frame.camera.trackingState)
            let points = frame.rawFeaturePoints.map { Array($0.points) } ?? []

            var densePoints: [SIMD3<Float>] = []
            if trackingNormal,
               frame.timestamp - lastPointCloudTimestamp >= captureQuality.denseSampleInterval,
               let depth {
                lastPointCloudTimestamp = frame.timestamp
                densePoints = DepthPointCloudBuilder.worldPoints(
                    depthMap: depth.depthMap,
                    confidenceMap: depth.confidenceMap,
                    camera: frame.camera,
                    sampleStride: captureQuality.depthSampleStride,
                    minimumConfidence: 1,
                    maximumDepth: 6.0
                )
            }
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
                    trackingIsNormal: trackingNormal,
                    yaw: yaw,
                    pitch: pitch,
                    cameraPosition: position,
                    timestamp: frame.timestamp,
                    depthResolution: resolution,
                    confidence: confidence,
                    exposureDuration: frame.camera.exposureDuration,
                    exposureOffset: frame.camera.exposureOffset,
                    depthStatistics: depthStatistics,
                    depthPreview: depthPreview,
                    confidencePreview: confidencePreview,
                    densePoints: densePoints
                )
            }
        }

        func sessionWasInterrupted(_ session: ARSession) {
            Task { @MainActor [weak controller] in
                controller?.setInterrupted(true)
            }
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            Task { @MainActor [weak controller] in
                controller?.setInterrupted(false)
            }

            guard running, let arView else { return }
            runSession(on: arView, resetTracking: false, clearPointCloud: false)
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            Task { @MainActor [weak controller] in
                controller?.setSessionError(error.localizedDescription)
            }
        }
    }
}
