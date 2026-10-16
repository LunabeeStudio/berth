import Foundation
import Testing

@testable import BerthDaemon

@Suite
struct ExecutableWatchTests {
    private func makeFile(_ content: String) throws -> URL {
        let url: URL = FileManager.default.temporaryDirectory.appending(path: "berth-watch-\(UUID().uuidString)")
        try Data(content.utf8).write(to: url)
        return url
    }

    @Test
    func `unchanged file is not reported`() throws {
        let url: URL = try makeFile("a")
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(!ExecutableWatch(path: url.path).hasChanged())
    }

    @Test
    func `file replaced by rename is reported`() throws {
        let url: URL = try makeFile("a")
        let replacement: URL = try makeFile("bb")
        defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: replacement) }
        let watch: ExecutableWatch = .init(path: url.path)

        #expect(rename(replacement.path, url.path) == 0)

        #expect(watch.hasChanged())
    }

    @Test
    func `vanished file is not reported`() throws {
        let url: URL = try makeFile("a")
        let watch: ExecutableWatch = .init(path: url.path)
        try FileManager.default.removeItem(at: url)

        #expect(!watch.hasChanged())
    }
}
