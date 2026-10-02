import Foundation

enum ProjectStoreError: Error {
    case documentsDirectoryUnavailable
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
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let url = root.appendingPathComponent("project.json")
        let data = try encoder.encode(project)
        try data.write(to: url, options: .atomic)
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

    func deleteProject(id: UUID) throws {
        let directory = try projectDirectory(for: id)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func projectDirectory(for id: UUID) throws -> URL {
        try projectsRoot().appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func projectsRoot() throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ProjectStoreError.documentsDirectoryUnavailable
        }

        return documents
            .appendingPathComponent("LiDARForge", isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)
    }
}
