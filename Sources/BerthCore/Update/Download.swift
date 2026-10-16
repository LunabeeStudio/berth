import Foundation

enum Download {
    /// - Throws: `UpdateError.http` for a non-200 HTTP answer. Other schemes (`file://` in tests) have no status to check.
    static func data(from url: URL) async throws -> Data {
        let request: URLRequest = .init(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let (data, response): (Data, URLResponse) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw UpdateError.http(status: http.statusCode, url: url.absoluteString)
        }
        return data
    }
}
