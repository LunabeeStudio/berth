import BerthCore
import Foundation
import Testing

@testable import BerthDaemon

@Suite
struct AutoUpdateFlagTests {
    private static func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("berth-flag-\(UUID().uuidString).json")
    }

    @Test
    func `reads the file each time`() throws {
        let url: URL = Self.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let flag: AutoUpdateFlag = .init(configURL: url, initial: false)

        try Config(autoUpdate: true).save(to: url)
        #expect(flag.isEnabled())

        try Config(autoUpdate: false).save(to: url)
        #expect(!flag.isEnabled())
    }

    @Test
    func `a malformed file keeps the last good value and logs`() throws {
        let url: URL = Self.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let lines: LockedLines = .init()
        let flag: AutoUpdateFlag = .init(configURL: url, initial: true, log: { lines.add($0) })
        try Config(autoUpdate: false).save(to: url)
        #expect(!flag.isEnabled())

        try Data("{ nope".utf8).write(to: url)

        #expect(!flag.isEnabled())
        #expect(lines.count == 1)
    }

    @Test
    func `a missing file keeps the last good value`() throws {
        let url: URL = Self.temporaryURL()
        let flag: AutoUpdateFlag = .init(configURL: url, initial: false)
        #expect(!flag.isEnabled())

        try Config(autoUpdate: true).save(to: url)
        #expect(flag.isEnabled())
        try FileManager.default.removeItem(at: url)

        #expect(flag.isEnabled())
    }
}
