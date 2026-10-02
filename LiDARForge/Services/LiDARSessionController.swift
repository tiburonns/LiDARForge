import ARKit
import Combine
import CoreGraphics
import CoreVideo
import Foundation
import UIKit

@MainActor
final class LiDARSessionController: ObservableObject {
    @Published private(set) var coverage: Double = 0
    @Published private(set) var confidence: Double?
    @Published private(set) var featurePointCount: Int = 0
    @Published private(set) var meshAnchorCount: Int = 0
    @Published private(set) var trackingDescription: String = "—"
    @Published private(set) var depthResolution: CGSize = .zero
    @Published private(set) var depthPreview: UIImage?
    @Published private(set) var confidencePreview: UIImage?
    @Published private(set) var supportsDepth = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    @Published private(set) var supportsMesh = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)

    private var orientationBins = Set<String>()
    private var spatialCells = Set<String>()
    private var startedAt = Date()

    func reset() {
        orientationBins.removeAll()
        spatialCells.removeAll()
        coverage = 0
        confidence = nil
        featurePointCount = 0
        meshAnchorCount = 0
        trackingDescription = "—"
        depthResolution = .zero
        depthPreview = nil
        confidencePreview = nil
        startedAt = Date()
    }

    func update(
        featurePoints: Int,
        meshAnchors: Int,
        tracking: String,
        yaw: Float,
        pitch: Float,
        cameraPosition: SIMD3<Float>,
        depthResolution: CGSize,
        confidence: Double?,
        depthPreview: UIImage?,
        confidencePreview: UIImage?
    ) {
        featurePointCount = featurePoints
        meshAnchorCount = meshAnchors
        trackingDescription = tracking
        self.depthResolution = depthResolution
        self.confidence = confidence

        if let depthPreview {
            self.depthPreview = depthPreview
        }
        if let confidencePreview {
            self.confidencePreview = confidencePreview
        }

        let yawBin = Int(((Double(yaw) + .pi) / (2 * .pi) * 12).rounded(.down))
        let pitchBand = Int(((Double(pitch) + (.pi / 2)) / .pi * 3).rounded(.down))
        orientationBins.insert("\(max(0, min(11, yawBin))):\(max(0, min(2, pitchBand)))")

        let cellSize: Float = 0.5
        let x = Int(floor(cameraPosition.x / cellSize))
        let y = Int(floor(cameraPosition.y / cellSize))
        let z = Int(floor(cameraPosition.z / cellSize))
        spatialCells.insert("\(x):\(y):\(z)")

        let orientationScore = min(Double(orientationBins.count) / 18.0, 1)
        let movementScore = min(Double(spatialCells.count) / 14.0, 1)
        let geometryScore = min(Double(meshAnchors) / 24.0, 1)
        let timeScore = min(Date().timeIntervalSince(startedAt) / 45.0, 1)

        coverage = min(
            1,
            orientationScore * 0.35 +
            movementScore * 0.30 +
            geometryScore * 0.25 +
            timeScore * 0.10
        )
    }

    var snapshot: ScanMetricsSnapshot {
        ScanMetricsSnapshot(
            coverage: coverage,
            confidence: confidence,
            featurePointCount: featurePointCount,
            meshAnchorCount: meshAnchorCount,
            trackingDescription: trackingDescription,
            depthWidth: Int(depthResolution.width),
            depthHeight: Int(depthResolution.height)
        )
    }
}

enum LiDARFrameProcessor {
    static func trackingDescription(_ state: ARCamera.TrackingState) -> String {
        switch state {
        case .normal:
            return "Normal"
        case .notAvailable:
            return "Unavailable"
        case .limited(let reason):
            switch reason {
            case .initializing: return "Initializing"
            case .excessiveMotion: return "Move slower"
            case .insufficientFeatures: return "Need more visual detail"
            case .relocalizing: return "Relocalizing"
            @unknown default: return "Limited"
            }
        }
    }

    static func confidenceScore(from pixelBuffer: CVPixelBuffer?) -> Double? {
        guard let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pointer = base.assumingMemoryBound(to: UInt8.self)

        var total = 0.0
        var samples = 0
        let step = max(1, min(width, height) / 48)

        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let value = pointer[y * bytesPerRow + x]
                total += min(Double(value), 2.0) / 2.0
                samples += 1
            }
        }

        return samples > 0 ? total / Double(samples) : nil
    }

    static func depthImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let rowStride = bytesPerRow / MemoryLayout<Float32>.size
        let pointer = base.assumingMemoryBound(to: Float32.self)

        var pixels = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let distance = pointer[y * rowStride + x]
                guard distance.isFinite, distance > 0 else { continue }

                let normalized = max(0, min((distance - 0.20) / 4.80, 1))
                pixels[y * width + x] = UInt8((1 - normalized) * 255)
            }
        }

        return grayscaleImage(bytes: pixels, width: width, height: height)
    }

    static func confidenceImage(from pixelBuffer: CVPixelBuffer?) -> UIImage? {
        guard let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pointer = base.assumingMemoryBound(to: UInt8.self)

        var pixels = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let level = min(pointer[y * bytesPerRow + x], 2)
                pixels[y * width + x] = UInt8(Double(level) / 2.0 * 255)
            }
        }

        return grayscaleImage(bytes: pixels, width: width, height: height)
    }

    private static func grayscaleImage(bytes: [UInt8], width: Int, height: Int) -> UIImage? {
        let data = Data(bytes)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            return nil
        }

        return UIImage(cgImage: image, scale: 1, orientation: .right)
    }
}
