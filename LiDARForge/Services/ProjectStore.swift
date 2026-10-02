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

    func save(_ project: ScanProject) throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ProjectStoreError.documentsDirectoryUnavailable
        }

        let root = documents
            .appendingPathComponent("LiDARForge", isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)
            .appendingPathComponent(project.id.uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let url = root.appendingPathComponent("project.json")
        let data = try encoder.encode(project)
        try data.write(to: url, options: .atomic)
        return url
    }
}
