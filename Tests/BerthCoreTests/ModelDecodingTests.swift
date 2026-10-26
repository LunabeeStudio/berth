import Foundation
import Testing

@testable import BerthCore

@Suite
struct ModelDecodingTests {
    @Test
    func `a slot saved before windowed existed decodes as headless`() throws {
        let json: String = #"{"serial":"emulator-5554","model":"Pixel","state":"free","stateSince":0,"generation":1}"#

        let slot: Slot = try Wire.decoder().decode(Slot.self, from: Data(json.utf8))

        #expect(slot.windowed == false)
    }

    @Test
    func `windowed survives an encode decode round trip`() throws {
        let slot: Slot = .mock(windowed: true)

        let data: Data = try Wire.encoder().encode(slot)

        #expect(try Wire.decoder().decode(Slot.self, from: data).windowed)
    }

    @Test
    func `a lease saved before manual existed decodes as agent lease`() throws {
        let json: String = #"{"id":"a","owner":{"pid":1,"name":"x"},"grantedAt":0,"expiresAt":0,"acknowledged":true}"#

        let lease: Lease = try Wire.decoder().decode(Lease.self, from: Data(json.utf8))

        #expect(lease.manual == false)
    }

    @Test
    func `a snapshot saved before adbRestartedAt existed decodes with no notice`() throws {
        let json: String = #"{"slots":[],"queue":[],"maxRunning":2,"pool":[],"generatedAt":0}"#

        let snapshot: StateSnapshot = try Wire.decoder().decode(StateSnapshot.self, from: Data(json.utf8))

        #expect(snapshot.adbRestartedAt == nil)
        #expect(snapshot.adbNotice(now: .init(timeIntervalSince1970: 0)) == nil)
    }

    @Test
    func `adbRestartedAt survives an encode decode round trip`() throws {
        let restartedAt: Date = .init(timeIntervalSince1970: 100)

        let data: Data = try Wire.encoder().encode(StateSnapshot.mock(adbRestartedAt: restartedAt))

        #expect(try Wire.decoder().decode(StateSnapshot.self, from: data).adbRestartedAt == restartedAt)
    }
}
