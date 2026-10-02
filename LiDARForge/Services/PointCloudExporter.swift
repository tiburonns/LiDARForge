import Foundation
import simd

enum PointCloudExportError: Error {
    case noPoints
}

enum PointCloudExporter {
    static func exportPLY(
        points: [SIMD3<Float>],
        projectID: UUID
    ) throws -> URL {
        guard !points.isEmpty else {
            throw PointCloudExportError.noPoints
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiDARForgeExports", isDirectory: true)

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        let url = root.appendingPathComponent("\(projectID.uuidString).ply")

        var output = """
        ply
        format ascii 1.0
        comment LiDARForge sparse AR feature-point export
        element vertex \(points.count)
        property float x
        property float y
        property float z
        end_header

        """

        output.reserveCapacity(output.count + points.count * 36)

        for point in points {
            output += "\(point.x) \(point.y) \(point.z)\n"
        }

        try output.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
