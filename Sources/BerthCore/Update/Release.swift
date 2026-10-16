import Foundation

/// Subset of the GitHub release JSON the updater reads.
public struct Release: Codable, Sendable {
    public let tagName: String
    public let assets: [Asset]

    public var version: SemanticVersion? { SemanticVersion(tagName) }

    public struct Asset: Codable, Sendable {
        public let name: String
        public let browserDownloadUrl: URL
    }

    public func asset(named name: String) -> Asset? {
        assets.first { $0.name == name }
    }
}
