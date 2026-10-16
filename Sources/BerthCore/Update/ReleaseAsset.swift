import Foundation

extension Release {
    public struct Asset: Codable, Sendable {
        public let name: String
        public let browserDownloadUrl: URL
    }
}
