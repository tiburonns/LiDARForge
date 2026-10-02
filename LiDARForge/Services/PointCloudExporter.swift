import ARKit
import CoreVideo
import Foundation
import simd

enum PointCloudExportError: Error {
    case noPoints
}

enum PointCloudSource: String {
    case sceneDepth
    case featurePoints
}

struct PointCloudSnapshot {
    let points: [SIMD3<Float>]
    let source: PointCloudSource
}

enum DepthPointCloudBuilder {
    /// Back-projects a sampled SceneDepth frame into ARKit world coordinates.
    ///
    /// Scene depth is aligned to the camera image but has a lower resolution.
    /// Camera intrinsics are scaled to the depth-map dimensions before
    /// back-projection. Medium/high confidence samples are preferred.
    static func worldPoints(
        depthMap: CVPixelBuffer,
        confidenceMap: CVPixelBuffer?,
        camera: ARCamera,
        sampleStride: Int = 6,
        minimumConfidence: UInt8 = 1,
        maximumDepth: Float = 6.0
    ) -> [SIMD3<Float>] {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        if let confidenceMap {
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
        }

        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            if let confidenceMap {
                CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly)
            }
        }

        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap) else {
            return []
        }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 0, height > 0 else { return [] }

        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let depthRowStride = depthBytesPerRow / MemoryLayout<Float32>.size
        let depthPointer = depthBase.assumingMemoryBound(to: Float32.self)

        let confidencePointer: UnsafeMutablePointer<UInt8>?
        let confidenceBytesPerRow: Int
        if let confidenceMap,
           let confidenceBase = CVPixelBufferGetBaseAddress(confidenceMap) {
            confidencePointer = confidenceBase.assumingMemoryBound(to: UInt8.self)
            confidenceBytesPerRow = CVPixelBufferGetBytesPerRow(confidenceMap)
        } else {
            confidencePointer = nil
            confidenceBytesPerRow = 0
        }

        let imageResolution = camera.imageResolution
        guard imageResolution.width > 0, imageResolution.height > 0 else {
            return []
        }

        let scaleX = Float(width) / Float(imageResolution.width)
        let scaleY = Float(height) / Float(imageResolution.height)

        let intrinsics = camera.intrinsics
        let fx = intrinsics.columns.0.x * scaleX
        let fy = intrinsics.columns.1.y * scaleY
        let cx = intrinsics.columns.2.x * scaleX
        let cy = intrinsics.columns.2.y * scaleY

        guard fx > 0, fy > 0 else { return [] }

        let stride = max(1, sampleStride)
        var points: [SIMD3<Float>] = []
        points.reserveCapacity((width / stride) * (height / stride))

        for v in Swift.stride(from: 0, to: height, by: stride) {
            for u in Swift.stride(from: 0, to: width, by: stride) {
                if let confidencePointer {
                    let confidence = confidencePointer[v * confidenceBytesPerRow + u]
                    if confidence < minimumConfidence {
                        continue
                    }
                }

                let depth = depthPointer[v * depthRowStride + u]
                guard depth.isFinite, depth > 0.10, depth <= maximumDepth else {
                    continue
                }

                // ARKit camera coordinates: +X right, +Y up, camera looks toward -Z.
                let x = (Float(u) - cx) * depth / fx
                let y = -(Float(v) - cy) * depth / fy
                let cameraPoint = SIMD4<Float>(x, y, -depth, 1)
                let worldPoint = camera.transform * cameraPoint

                points.append(
                    SIMD3<Float>(worldPoint.x, worldPoint.y, worldPoint.z)
                )
            }
        }

        return points
    }
}

enum PointCloudExporter {
    static func exportPLY(
        snapshot: PointCloudSnapshot,
        projectID: UUID
    ) throws -> URL {
        guard !snapshot.points.isEmpty else {
            throw PointCloudExportError.noPoints
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiDARForgeExports", isDirectory: true)

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        let suffix = snapshot.source == .sceneDepth ? "lidar" : "features"
        let url = root.appendingPathComponent(
            "\(projectID.uuidString)-\(suffix).ply"
        )

        let sourceComment: String
        switch snapshot.source {
        case .sceneDepth:
            sourceComment = "LiDARForge SceneDepth point cloud"
        case .featurePoints:
            sourceComment = "LiDARForge sparse AR feature-point fallback"
        }

        var output = """
        ply
        format ascii 1.0
        comment \(sourceComment)
        element vertex \(snapshot.points.count)
        property float x
        property float y
        property float z
        end_header

        """

        output.reserveCapacity(output.count + snapshot.points.count * 36)

        for point in snapshot.points {
            output += "\(point.x) \(point.y) \(point.z)\n"
        }

        try output.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
