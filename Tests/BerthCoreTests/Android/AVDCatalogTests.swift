import Foundation
import Testing

@testable import BerthCore

@Suite
struct AVDCatalogTests {
    private static func temporaryHome() throws -> URL {
        let home: URL = FileManager.default.temporaryDirectory.appending(path: "berth-avd-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    @Test
    func `directory follows the path line of the ini`() throws {
        let home: URL = try Self.temporaryHome()
        try "avd.ini.encoding=UTF-8\npath=/elsewhere/Pixel.avd\n".write(to: home.appending(path: "Pixel.ini"), atomically: true, encoding: .utf8)

        #expect(AVDCatalog.directory(of: "Pixel", home: home).path == "/elsewhere/Pixel.avd")
    }

    @Test
    func `directory falls back to the avd folder under home`() throws {
        let home: URL = try Self.temporaryHome()

        #expect(AVDCatalog.directory(of: "Pixel", home: home) == home.appending(path: "Pixel.avd"))
    }

    @Test
    func `hasSnapshot sees the named snapshot folder only`() throws {
        let home: URL = try Self.temporaryHome()
        let snapshots: URL = home.appending(path: "Pixel.avd/snapshots/berth-clean")
        try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)

        #expect(AVDCatalog.hasSnapshot("berth-clean", model: "Pixel", home: home))
        #expect(!AVDCatalog.hasSnapshot("other", model: "Pixel", home: home))
        #expect(!AVDCatalog.hasSnapshot("berth-clean", model: "Missing", home: home))
    }
}
