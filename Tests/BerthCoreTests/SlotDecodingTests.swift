import Foundation
import Testing

@testable import BerthCore

@Suite
struct SlotDecodingTests {
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
}
