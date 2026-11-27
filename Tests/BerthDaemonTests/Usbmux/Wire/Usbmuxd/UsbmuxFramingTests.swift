@testable import BerthDaemon
import Foundation
import Testing

@Suite
struct UsbmuxFramingTests {
    @Test
    func `header is 16 little-endian bytes: length, version 1, type 8, tag`() {
        let frame: Data = UsbmuxFraming.frame(Data("abc".utf8), tag: 5)

        #expect(Array(frame.prefix(16)) == [19, 0, 0, 0, 1, 0, 0, 0, 8, 0, 0, 0, 5, 0, 0, 0])
        #expect(frame.suffix(3) == Data("abc".utf8))
    }

    @Test
    func `receive returns the payload after the header`() throws {
        let connection: FakeUsbmuxConnection = .init(replies: [UsbmuxFraming.frame(Data("hello".utf8))])

        let payload: Data = try UsbmuxFraming.receive(from: connection)

        #expect(payload == Data("hello".utf8))
    }

    @Test
    func `a length shorter than the header is a malformed reply`() {
        let connection: FakeUsbmuxConnection = .init(replies: [Data([4, 0, 0, 0, 1, 0, 0, 0, 8, 0, 0, 0, 1, 0, 0, 0])])

        #expect(throws: UsbmuxError.malformedReply) { try UsbmuxFraming.receive(from: connection) }
    }

    @Test
    func `a truncated reply is a closed connection`() {
        let connection: FakeUsbmuxConnection = .init(replies: [Data(UsbmuxFraming.frame(Data("hello".utf8)).dropLast(2))])

        #expect(throws: UsbmuxError.closed) { try UsbmuxFraming.receive(from: connection) }
    }
}
