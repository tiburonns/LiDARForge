import Foundation

enum ProjectStoreError: Error {
    case documentsDirectoryUnavailable
    case projectUnavailable
}

struct ProjectArtifacts {
    let pointCloudURL: URL?
    let packageURL: URL?
}

actor ProjectStore {
    static let shared = ProjectStore()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func save(_ project: ScanProject) throws -> URL {
        let root = try projectDirectory(for: project.id)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        let url = root.appendingPathComponent("project.json")
        let data = try encoder.encode(project)
        try data.write(to: url, options: .atomic)
        return url
    }

    func savePointCloud(
        _ snapshot: PointCloudSnapshot,
        projectID: UUID
    ) throws -> URL {
        guard !snapshot.points.isEmpty else {
            throw PointCloudExportError.noPoints
        }

        let root = try projectDirectory(for: projectID)
        let pointCloudDirectory = root.appendingPathComponent(
            "pointcloud",
            isDirectory: true
        )

        let filename = snapshot.source == .sceneDepth
            ? "scene-depth.ply"
            : "feature-points.ply"

        let url = pointCloudDirectory.appendingPathComponent(filename)

        try PointCloudExporter.writePLY(
            snapshot: snapshot,
            to: url
        )

        return url
    }

    func listProjects() -> [ScanProject] {
        guard let root = try? projectsRoot(),
              let directories = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        return directories.compactMap { directory in
            let url = directory.appendingPathComponent("project.json")
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(ScanProject.self, from: data)
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    func project(id: UUID) throws -> ScanProject {
        let url = try projectDirectory(for: id)
            .appendingPathComponent("project.json")

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProjectStoreError.projectUnavailable
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(ScanProject.self, from: data)
    }

    func pointCloudURL(projectID: UUID) throws -> URL? {
        let root = try projectDirectory(for: projectID)
            .appendingPathComponent("pointcloud", isDirectory: true)

        let dense = root.appendingPathComponent("scene-depth.ply")
        if FileManager.default.fileExists(atPath: dense.path) {
            return dense
        }

        let sparse = root.appendingPathComponent("feature-points.ply")
        if FileManager.default.fileExists(atPath: sparse.path) {
            return sparse
        }

        return nil
    }

    func buildSharePackage(projectID: UUID) throws -> URL {
        let source = try projectDirectory(for: projectID)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw ProjectStoreError.projectUnavailable
        }

        let exportsRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "LiDARForgePackages",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: exportsRoot,
            withIntermediateDirectories: true
        )

        let destination = exportsRoot.appendingPathComponent(
            "\(projectID.uuidString).lidarforge",
            isDirectory: true
        )

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.copyItem(
            at: source,
            to: destination
        )

        let manifest = LiDARForgePackageManifest(
            formatVersion: 1,
            projectID: projectID,
            createdAt: Date(),
            files: try packageRelativeFiles(root: destination)
        )

        let manifestData = try encoder.encode(manifest)
        try manifestData.write(
            to: destination.appendingPathComponent("manifest.json"),
            options: .atomic
        )

        return destination
    }

    func artifacts(projectID: UUID) throws -> ProjectArtifacts {
        ProjectArtifacts(
            pointCloudURL: try pointCloudURL(projectID: projectID),
            packageURL: nil
        )
    }

    func deleteProject(id: UUID) throws {
        let directory = try projectDirectory(for: id)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func projectDirectory(for id: UUID) throws -> URL {
        try projectsRoot().appendingPathComponent(
            id.uuidString,
            isDirectory: true
        )
    }

    private func projectsRoot() throws -> URL {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw ProjectStoreError.documentsDirectoryUnavailable
        }

        let root = documents
            .appendingPathComponent("LiDARForge", isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        return root
    }

    private func packageRelativeFiles(root: URL) throws -> [String] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [String] = []

        for case let url as URL in enumerator {
            let values = try url.resourceValues(
                forKeys: [.isRegularFileKey]
            )

            guard values.isRegularFile == true else { continue }

            let relative = url.path.replacingOccurrences(
                of: root.path + "/",
                with: ""
            )

            if relative != "manifest.json" {
                files.append(relative)
            }
        }

        return files.sorted()
    }
}

private struct LiDARForgePackageManifest: Codable {
    let formatVersion: Int
    let projectID: UUID
    let createdAt: Date
    let files: [String]
}
