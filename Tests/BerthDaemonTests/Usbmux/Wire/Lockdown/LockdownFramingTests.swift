@testable import BerthDaemon
import Foundation
import Testing

@Suite
struct LockdownFramingTests {
    @Test
    func `frame prefixes the payload with its big-endian length`() {
        let frame: Data = LockdownFraming.frame(Data("abc".utf8))

        #expect(Array(frame.prefix(4)) == [0, 0, 0, 3])
        #expect(frame.suffix(3) == Data("abc".utf8))
    }

    @Test
    func `receive reads the length then the payload`() throws {
        let connection: FakeUsbmuxConnection = .init(replies: [LockdownFraming.frame(Data("hello".utf8))])

        let payload: Data = try LockdownFraming.receive(from: connection)

        #expect(payload == Data("hello".utf8))
    }

    @Test
    func `an absurd length is a malformed reply`() {
        let connection: FakeUsbmuxConnection = .init(replies: [Data([0xFF, 0xFF, 0xFF, 0xFF])])

        #expect(throws: UsbmuxError.malformedReply) { try LockdownFraming.receive(from: connection) }
    }
}
