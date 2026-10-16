import BerthCore
import Foundation
import Testing

@Suite
struct ConfigTests {
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
}
