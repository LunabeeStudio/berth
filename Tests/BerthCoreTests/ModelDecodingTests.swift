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
}
