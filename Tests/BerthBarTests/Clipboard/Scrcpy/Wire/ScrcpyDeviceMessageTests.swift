import Testing

@testable import BerthBar

@Suite
struct ScrcpyDeviceMessageTests {
    @Test
    func `decodes a clipboard message`() throws {
        let message: ScrcpyDeviceMessage = try #require(try ScrcpyDeviceMessage.decode(Self.clipboard("hello")))

        #expect(message == .clipboard("hello"))
    }

    @Test
    func `decodes accents, emoji and several lines unchanged`() throws {
        let text: String = "Café déjà vu\nligne deux 🎉👩‍👩‍👧\r\n日本語\n"

        let message: ScrcpyDeviceMessage = try #require(try ScrcpyDeviceMessage.decode(Self.clipboard(text)))

        #expect(message == .clipboard(text))
    }

    @Test
    func `decodes an empty text`() throws {
        let message: ScrcpyDeviceMessage = try #require(try ScrcpyDeviceMessage.decode([0, 0, 0, 0, 0]))

        #expect(message == .clipboard(""))
    }

    @Test
    func `ignores bytes that follow the message`() throws {
        let message: ScrcpyDeviceMessage = try #require(try ScrcpyDeviceMessage.decode(Self.clipboard("ab") + [1, 2, 3]))

        #expect(message == .clipboard("ab"))
    }

    @Test
    func `reads a length above 255 across the big endian bytes`() throws {
        let text: String = .init(repeating: "x", count: 300)

        let message: ScrcpyDeviceMessage = try #require(try ScrcpyDeviceMessage.decode(Self.clipboard(text)))

        #expect(message == .clipboard(text))
    }

    @Test
    func `waits for more bytes while the input is truncated`() throws {
        let whole: [UInt8] = Self.clipboard("héllo")

        #expect(try ScrcpyDeviceMessage.decode([]) == nil)
        for length in 1 ..< whole.count {
            #expect(try ScrcpyDeviceMessage.decode(Array(whole.prefix(length))) == nil)
        }
        #expect(try ScrcpyDeviceMessage.decode(whole) != nil)
    }

    @Test
    func `rejects an unknown message type`() {
        #expect(throws: ScrcpyDeviceMessage.DecodingError.unknownType(1)) {
            try ScrcpyDeviceMessage.decode([1, 0, 0, 0, 0, 0, 0, 0, 0])
        }
    }

    @Test
    func `rejects a length above the protocol limit`() {
        #expect(throws: ScrcpyDeviceMessage.DecodingError.textTooLong(0x7fff_ffff)) {
            try ScrcpyDeviceMessage.decode([0, 0x7f, 0xff, 0xff, 0xff])
        }
    }

    static func clipboard(_ text: String) -> [UInt8] {
        let payload: [UInt8] = Array(text.utf8)
        let length: [UInt8] = (0 ..< 4).map { UInt8(truncatingIfNeeded: payload.count >> (8 * (3 - $0))) }
        return [0] + length + payload
    }
}
