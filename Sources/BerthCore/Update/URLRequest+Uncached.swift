import Foundation

extension URLRequest {
    static func uncached(_ url: URL) -> URLRequest {
        .init(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
    }
}
