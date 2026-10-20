import BerthCore
import Foundation
import Testing

@testable import BerthBar

@MainActor
@Suite
struct AutoUpdateSettingTests {
    private static func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("berth-setting-\(UUID().uuidString).json")
    }

    private static func object(at url: URL) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    @Test
    func `a missing key reads true`() throws {
        let url: URL = Self.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"maxRunning": 2}"#.utf8).write(to: url)

        let setting: AutoUpdateSetting = .init(configURL: url)

        #expect(setting.isAvailable)
        #expect(setting.isEnabled)
    }

    @Test(arguments: [true, false])
    func `the stored value reads back`(value: Bool) throws {
        let url: URL = Self.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Config(autoUpdate: value).save(to: url)

        let setting: AutoUpdateSetting = .init(configURL: url)

        #expect(setting.isAvailable)
        #expect(setting.isEnabled == value)
    }

    @Test
    func `toggling changes only autoUpdate and keeps unknown and absent keys`() throws {
        let url: URL = Self.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let json: String = #"{"sdkRoot": "/opt/sdk", "maxRunning": 7, "future": {"a": [1, 2]}, "pool": [{"avd": "Pixel_8", "maxInstances": 3}, {"simulator": "iPhone 17", "maxInstances": 1}]}"#
        try Data(json.utf8).write(to: url)
        let setting: AutoUpdateSetting = .init(configURL: url)
        let before: [String: Any] = try Self.object(at: url)

        setting.isEnabled = false
        var expected: [String: Any] = before
        expected["autoUpdate"] = false
        #expect(NSDictionary(dictionary: try Self.object(at: url)).isEqual(to: expected))
        #expect(!setting.isEnabled)

        setting.isEnabled = true
        expected["autoUpdate"] = true
        #expect(NSDictionary(dictionary: try Self.object(at: url)).isEqual(to: expected))
        #expect(setting.isEnabled)
    }

    @Test
    func `a missing file is unavailable and never created`() {
        let url: URL = Self.temporaryURL()
        let setting: AutoUpdateSetting = .init(configURL: url)

        setting.isEnabled = false

        #expect(!setting.isAvailable)
        #expect(setting.isEnabled)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func `a malformed file is unavailable and left untouched`() throws {
        let url: URL = Self.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("{ nope".utf8).write(to: url)
        let setting: AutoUpdateSetting = .init(configURL: url)

        setting.isEnabled = false

        #expect(!setting.isAvailable)
        #expect(try Data(contentsOf: url) == Data("{ nope".utf8))
    }

    @Test
    func `refresh picks up a hand edit`() throws {
        let url: URL = Self.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Config(autoUpdate: true).save(to: url)
        let setting: AutoUpdateSetting = .init(configURL: url)

        try Config(autoUpdate: false).save(to: url)
        setting.refresh()

        #expect(!setting.isEnabled)
    }
}
