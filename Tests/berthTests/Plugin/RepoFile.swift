import Foundation

enum RepoFile {
    private static let root: URL = .init(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static func text(_ path: String) throws -> String {
        try String(contentsOf: url(path), encoding: .utf8)
    }

    static func json(_ path: String) throws -> [String: Any]? {
        try JSONSerialization.jsonObject(with: Data(contentsOf: url(path))) as? [String: Any]
    }

    private static func url(_ path: String) -> URL {
        root.appendingPathComponent(path)
    }
}
