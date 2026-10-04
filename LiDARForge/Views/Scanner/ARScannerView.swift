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
    var showSurfaceHeatmap: Bool = false
    var captureWorkspace: Bool = true
    var sessionRefreshID: UUID?

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
        context.coordinator.setCaptureWorkspace(captureWorkspace)
        context.coordinator.setViewMode(viewMode, on: view)
        context.coordinator.setRunning(isRunning, on: view)
        context.coordinator.handleSessionRefresh(
            sessionRefreshID,
            on: view
        )
        context.coordinator.setSurfaceHeatmap(
            showSurfaceHeatmap,
            cells: controller.surfaceCoverageCells,
            on: view
        )
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.setAllowsTargetLock(allowsTargetLock)
        context.coordinator.setMeasurementMode(measurementMode)
        context.coordinator.setCaptureQuality(captureQuality)
        context.coordinator.setRGBDRecorder(rgbdRecorder)
        context.coordinator.setInitialWorldMapData(initialWorldMapData)
        context.coordinator.setCaptureWorkspace(captureWorkspace)
        context.coordinator.setViewMode(viewMode, on: uiView)
        context.coordinator.setRunning(isRunning, on: uiView)
        context.coordinator.handleSessionRefresh(
            sessionRefreshID,
            on: uiView
        )
        context.coordinator.setSurfaceHeatmap(
            showSurfaceHeatmap,
            cells: controller.surfaceCoverageCells,
            on: uiView
        )
        context.coordinator.handleWorldMapSaveRequest(
            controller.worldMapSaveRequestID,
            on: uiView
        )
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.removeSurfaceHeatmap()
        coordinator.removeFeaturePointVisualization()
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
        private var lastMeshSurfaceTimestamp: TimeInterval = 0
        private var lastRGBDTimestamp: TimeInterval = 0
        private var lastHeatmapRender = Date.distantPast
        private var lastFeaturePointRender = Date.distantPast
        private var allowsTargetLock = false
        private var measurementMode = false
        private var captureQuality: CaptureQualityMode = .balanced
        private weak var rgbdRecorder: RGBDRecorder?
        private var captureWorkspace = true
        private var currentViewMode: SensorViewMode = .camera
        private var initialWorldMapData: Data?
        private var lastWorldMapSaveRequestID: UUID?
        private var lastSessionRefreshID: UUID?
        private var heatmapAnchor: AnchorEntity?
        private var featurePointAnchor: AnchorEntity?

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

        func setCaptureWorkspace(_ enabled: Bool) {
            captureWorkspace = enabled
        }

        func handleSessionRefresh(
            _ refreshID: UUID?,
            on view: ARView
        ) {
            guard let refreshID,
                  refreshID != lastSessionRefreshID,
                  running else {
                return
            }

            lastSessionRefreshID = refreshID
            runSession(
                on: view,
                resetTracking: false,
                clearPointCloud: false
            )
        }

        func setRGBDRecorder(_ recorder: RGBDRecorder?) {
            rgbdRecorder = recorder
        }

        func setInitialWorldMapData(_ data: Data?) {
            guard !hasStarted else { return }
            initialWorldMapData = data
        }

        func setSurfaceHeatmap(
            _ enabled: Bool,
            cells: [SurfaceCoverageCell],
            on view: ARView
        ) {
            guard enabled else {
                removeSurfaceHeatmap()
                return
            }

            guard Date().timeIntervalSince(lastHeatmapRender) >= 1.10 else {
                return
            }

            lastHeatmapRender = Date()
            removeSurfaceHeatmap()

            let gaps = cells
                .filter { $0.coverage < 0.82 }
                .sorted { lhs, rhs in
                    if lhs.coverage == rhs.coverage {
                        return lhs.confidence < rhs.confidence
                    }
                    return lhs.coverage < rhs.coverage
                }

            guard !gaps.isEmpty else { return }

            let anchor = AnchorEntity(world: .zero)
            let mesh = MeshResource.generateSphere(radius: 0.007)

            let missingMaterial = SimpleMaterial(
                color: UIColor.systemRed.withAlphaComponent(0.78),
                isMetallic: false
            )
            let weakMaterial = SimpleMaterial(
                color: UIColor.systemOrange.withAlphaComponent(0.68),
                isMetallic: false
            )
            let partialMaterial = SimpleMaterial(
                color: UIColor.systemYellow.withAlphaComponent(0.52),
                isMetallic: false
            )

            for cell in gaps.prefix(120) {
                let material: SimpleMaterial
                if cell.coverage < 0.20 {
                    material = missingMaterial
                } else if cell.coverage < 0.50 {
                    material = weakMaterial
                } else {
                    material = partialMaterial
                }

                let entity = ModelEntity(
                    mesh: mesh,
                    materials: [material]
                )
                entity.position = cell.position
                anchor.addChild(entity)
            }

            view.scene.addAnchor(anchor)
            heatmapAnchor = anchor
        }

        func removeSurfaceHeatmap() {
            heatmapAnchor?.removeFromParent()
            heatmapAnchor = nil
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

            let needsMesh =
                captureWorkspace ||
                currentViewMode == .mesh ||
                currentViewMode == .raw

            if needsMesh {
                if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                    configuration.sceneReconstruction = .meshWithClassification
                } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                    configuration.sceneReconstruction = .mesh
                }
            }

            let needsDepth =
                captureWorkspace ||
                currentViewMode == .depth ||
                currentViewMode == .confidence ||
                currentViewMode == .raw

            if needsDepth {
                if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
                    configuration.frameSemantics.insert(.smoothedSceneDepth)
                } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                    configuration.frameSemantics.insert(.sceneDepth)
                }
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
            currentViewMode = mode
            var options: ARView.DebugOptions = []

            switch mode {
            case .camera:
                break
            case .cameraPoints:
                break
            case .mesh:
                options.insert(.showSceneUnderstanding)
            case .depth, .confidence:
                break
            case .raw:
                options.insert(.showWorldOrigin)
            }

            if mode != .cameraPoints {
                removeFeaturePointVisualization()
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

            let confidence = LiDARFrameProcessor.confidenceScore(
                from: depth?.confidenceMap
            )
            let depthStatistics = LiDARFrameProcessor.depthStatistics(
                from: depth?.depthMap
            )

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

            let previewInterval: TimeInterval
            switch currentViewMode {
            case .confidence:
                previewInterval = max(
                    0.28,
                    captureQuality.previewInterval * 1.8
                )
            case .depth:
                previewInterval = max(
                    0.18,
                    captureQuality.previewInterval
                )
            default:
                previewInterval = .infinity
            }

            if frame.timestamp - lastPreviewTimestamp >= previewInterval,
               let depth {
                lastPreviewTimestamp = frame.timestamp

                if currentViewMode == .depth {
                    depthPreview = LiDARFrameProcessor.depthImage(
                        from: depth.depthMap
                    )
                } else if currentViewMode == .confidence {
                    confidencePreview = LiDARFrameProcessor.confidenceImage(
                        from: depth.confidenceMap
                    )
                }
            }

            let transform = frame.camera.transform
            let position = SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )

            let tracking = LiDARFrameProcessor.trackingDescription(
                frame.camera.trackingState
            )
            let trackingNormal = LiDARFrameProcessor.isTrackingNormal(
                frame.camera.trackingState
            )
            let points = frame.rawFeaturePoints.map {
                Array($0.points)
            } ?? []

            if currentViewMode == .cameraPoints,
               Date().timeIntervalSince(lastFeaturePointRender) >= 0.28 {
                lastFeaturePointRender = Date()
                let sample = Array(points.prefix(80))

                DispatchQueue.main.async { [weak self] in
                    guard let self,
                          let view = self.arView else {
                        return
                    }

                    self.renderFeaturePoints(
                        sample,
                        on: view
                    )
                }
            }

            var densePoints: [SIMD3<Float>] = []
            let denseInterval = currentViewMode == .confidence
                ? max(0.90, captureQuality.denseSampleInterval)
                : captureQuality.denseSampleInterval

            if trackingNormal,
               captureWorkspace,
               currentViewMode != .confidence,
               frame.timestamp - lastPointCloudTimestamp >= denseInterval,
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

            var meshSurfacePoints: [SIMD3<Float>] = []
            if trackingNormal,
               captureWorkspace,
               currentViewMode != .confidence,
               frame.timestamp - lastMeshSurfaceTimestamp >= 0.95 {
                lastMeshSurfaceTimestamp = frame.timestamp
                meshSurfacePoints = sampledMeshSurfacePoints(
                    from: frame,
                    maxPerAnchor: captureQuality == .maximum ? 120 : 72
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
                    densePoints: densePoints,
                    meshSurfacePoints: meshSurfacePoints
                )
            }
        }

        private func sampledMeshSurfacePoints(
            from frame: ARFrame,
            maxPerAnchor: Int
        ) -> [SIMD3<Float>] {
            var result: [SIMD3<Float>] = []

            for anchor in frame.anchors {
                guard let meshAnchor = anchor as? ARMeshAnchor else {
                    continue
                }

                let source = meshAnchor.geometry.vertices
                guard source.count > 0 else { continue }

                let step = max(
                    1,
                    source.count / max(1, maxPerAnchor)
                )

                for index in stride(
                    from: 0,
                    to: source.count,
                    by: step
                ) {
                    let address = source.buffer.contents()
                        .advanced(
                            by: source.offset +
                                source.stride * index
                        )

                    let vertex = address
                        .assumingMemoryBound(to: SIMD3<Float>.self)
                        .pointee

                    let world = meshAnchor.transform * SIMD4<Float>(
                        vertex.x,
                        vertex.y,
                        vertex.z,
                        1
                    )

                    result.append(
                        SIMD3<Float>(
                            world.x,
                            world.y,
                            world.z
                        )
                    )

                    if result.count >= 1_200 {
                        return result
                    }
                }
            }

            return result
        }

        private func renderFeaturePoints(
            _ points: [SIMD3<Float>],
            on view: ARView
        ) {
            removeFeaturePointVisualization()

            guard !points.isEmpty else { return }

            let anchor = AnchorEntity(world: .zero)
            let mesh = MeshResource.generateSphere(radius: 0.0045)
            let material = SimpleMaterial(
                color: UIColor.systemCyan.withAlphaComponent(0.90),
                isMetallic: false
            )

            for point in points {
                let entity = ModelEntity(
                    mesh: mesh,
                    materials: [material]
                )
                entity.position = point
                anchor.addChild(entity)
            }

            view.scene.addAnchor(anchor)
            featurePointAnchor = anchor
        }

        func removeFeaturePointVisualization() {
            featurePointAnchor?.removeFromParent()
            featurePointAnchor = nil
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
            runSession(
                on: arView,
                resetTracking: false,
                clearPointCloud: false
            )
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            Task { @MainActor [weak controller] in
                controller?.setSessionError(error.localizedDescription)
            }
        }
    }
}
