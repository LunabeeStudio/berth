import Foundation
import Testing

@testable import BerthCore

@Suite
struct ProtocolDecodingTests {
    @Test
    func `an unknown slot state decodes as booting`() throws {
        let json: String = #""warming""#

        #expect(try Wire.decoder().decode(SlotState.self, from: Data(json.utf8)) == .booting)
    }

    @Test
    func `preparing survives an encode decode round trip`() throws {
        let data: Data = try Wire.encoder().encode(Slot.mock(state: .preparing))

        #expect(try Wire.decoder().decode(Slot.self, from: data).state == .preparing)
    }

    @Test
    func `prepare request survives an encode decode round trip`() throws {
        let data: Data = try Wire.encoder().encode(Request.prepare(.init(avd: "Pixel_9", settle: 20)))

        guard case let .prepare(request) = try Wire.decoder().decode(Request.self, from: data) else {
            Issue.record("expected prepare")
            return
        }
        #expect(request == PrepareRequest(avd: "Pixel_9", settle: 20))
    }

    @Test
    func `progress event survives an encode decode round trip`() throws {
        let data: Data = try Wire.encoder().encode(Event.progress("settling"))

        guard case let .progress(line) = try Wire.decoder().decode(Event.self, from: data) else {
            Issue.record("expected progress")
            return
        }
        #expect(line == "settling")
    }
}
