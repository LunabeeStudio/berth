import BerthCore
import Foundation
import Testing

@Suite
struct ConfigTests {
    private static func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("berth-config-\(UUID().uuidString).json")
    }

    @Test
    func `decodes android and ios pool entries`() throws {
        let json = #"{"pool": [{"avd": "Pixel_9", "maxInstances": 2}, {"simulator": "iPhone 17", "maxInstances": 3}]}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        #expect(config.pool == [
            PoolEntry(name: "Pixel_9", platform: .android, maxInstances: 2),
            PoolEntry(name: "iPhone 17", platform: .ios, maxInstances: 3),
        ])
    }

    @Test
    func `legacy avd-only config decodes unchanged`() throws {
        let json = #"{"maxRunning": 3, "pool": [{"avd": "Pixel_9", "maxInstances": 1}]}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        #expect(config.maxRunning == 3)
        #expect(config.pool.map(\.platform) == [.android])
        #expect(config.entry(for: "Pixel_9")?.maxInstances == 1)
    }

    @Test
    func `pool entries round trip with their original keys`() throws {
        let entries = [PoolEntry(name: "Pixel_9", maxInstances: 2), PoolEntry(name: "iPhone 17", platform: .ios, maxInstances: 1)]
        let data = try JSONEncoder().encode(entries)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(#""avd":"Pixel_9""#))
        #expect(text.contains(#""simulator":"iPhone 17""#))
        #expect(try JSONDecoder().decode([PoolEntry].self, from: data) == entries)
    }

    @Test
    func `pool entry without a device key is rejected`() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PoolEntry.self, from: Data(#"{"maxInstances": 1}"#.utf8))
        }
    }

    @Test
    func `autoUpdate defaults to true when the key is absent`() throws {
        let config: Config = try JSONDecoder().decode(Config.self, from: Data(#"{"maxRunning": 3}"#.utf8))
        #expect(config.autoUpdate)
    }

    @Test
    func `autoUpdate false is honoured`() throws {
        let config: Config = try JSONDecoder().decode(Config.self, from: Data(#"{"autoUpdate": false}"#.utf8))
        #expect(!config.autoUpdate)
    }

    @Test
    func `load returns nil when the file is missing and decodes it when present`() throws {
        let url: URL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
        #expect(try Config.load(from: url) == nil)

        try Data(#"{"maxRunning": 7}"#.utf8).write(to: url)
        #expect(try Config.load(from: url)?.maxRunning == 7)
    }

    @Test
    func `load throws on a malformed file`() throws {
        let url: URL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
        try Data("nope".utf8).write(to: url)

        #expect(throws: (any Error).self) { try Config.load(from: url) }
    }

    @Test
    func `pool lookup finds entries and defaults to android`() {
        let pool: [PoolEntry] = [.init(name: "Pixel_9", maxInstances: 2), .init(name: "iPhone 17", platform: .ios, maxInstances: 1)]

        #expect(pool.entry(for: "Pixel_9")?.maxInstances == 2)
        #expect(pool.entry(for: "none") == nil)
        #expect(pool.platform(of: "iPhone 17") == .ios)
        #expect(pool.platform(of: "none") == .android)
    }

    @Test
    func `save writes sorted pretty JSON that loads back`() throws {
        let url: URL = Self.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let config: Config = .init(maxRunning: 5, autoUpdate: false, pool: [PoolEntry(name: "Pixel_9", maxInstances: 2)])

        try config.save(to: url)

        let text: String = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        #expect(text.contains("\n  \"autoUpdate\" : false"))
        let autoUpdateIndex: Range<String.Index> = try #require(text.range(of: "autoUpdate"))
        let maxRunningIndex: Range<String.Index> = try #require(text.range(of: "maxRunning"))
        #expect(autoUpdateIndex.lowerBound < maxRunningIndex.lowerBound)
        let loaded: Config = try #require(try Config.load(from: url))
        #expect(loaded.maxRunning == 5)
        #expect(!loaded.autoUpdate)
        #expect(loaded.pool == config.pool)
    }

    @Test(arguments: ["[1, 2]", #"{"pool": [{"maxInstances": 1}]}"#, "{ nope"])
    func `setAutoUpdate throws on undecodable JSON and leaves the file untouched`(json: String) throws {
        let url: URL = Self.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(json.utf8).write(to: url)

        #expect(throws: (any Error).self) { try Config.setAutoUpdate(false, at: url) }

        #expect(try Data(contentsOf: url) == Data(json.utf8))
    }

    @Test
    func `setAutoUpdate throws on a missing file and creates nothing`() {
        let url: URL = Self.temporaryURL()

        #expect(throws: (any Error).self) { try Config.setAutoUpdate(false, at: url) }

        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func `setAutoUpdate keeps unknown keys`() throws {
        let url: URL = Self.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"future": {"a": [1, 2]}, "maxRunning": 3}"#.utf8).write(to: url)

        try Config.setAutoUpdate(false, at: url)

        let object: [String: Any] = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let expected: [String: Any] = ["future": ["a": [1, 2]], "maxRunning": 3, "autoUpdate": false]
        #expect(NSDictionary(dictionary: object).isEqual(to: expected))
    }
}
