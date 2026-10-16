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

    private func poll(_ watch: inout ExecutableWatch) -> Bool {
        watch.hasSettledChange()
    }

    @Test
    func `unchanged file is not reported`() throws {
        let url: URL = try makeFile("a")
        defer { try? FileManager.default.removeItem(at: url) }
        var watch: ExecutableWatch = .init(path: url.path)

        #expect(!poll(&watch))
        #expect(!poll(&watch))
    }

    @Test
    func `replaced file is reported on the second identical poll`() throws {
        let url: URL = try makeFile("a")
        let replacement: URL = try makeFile("bb")
        defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: replacement) }
        var watch: ExecutableWatch = .init(path: url.path)

        #expect(rename(replacement.path, url.path) == 0)

        #expect(!poll(&watch))
        #expect(poll(&watch))
    }

    @Test
    func `file still being written is not reported`() throws {
        let url: URL = try makeFile("a")
        defer { try? FileManager.default.removeItem(at: url) }
        var watch: ExecutableWatch = .init(path: url.path)

        try Data("bb".utf8).write(to: url)
        #expect(!poll(&watch))
        try Data("bbbbbb".utf8).write(to: url)
        #expect(!poll(&watch))
        #expect(poll(&watch))
    }

    @Test
    func `vanished file is not reported`() throws {
        let url: URL = try makeFile("a")
        var watch: ExecutableWatch = .init(path: url.path)
        try FileManager.default.removeItem(at: url)

        #expect(!poll(&watch))
        #expect(!poll(&watch))
    }
}
