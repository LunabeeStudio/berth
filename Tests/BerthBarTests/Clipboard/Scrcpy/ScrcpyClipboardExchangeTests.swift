import Testing

@testable import BerthBar

@Suite
struct ScrcpyClipboardExchangeTests {
    private static let dummyByte: ScrcpyReadOutcome = .bytes([0])

    private static func read(
        _ channels: [FakeControlChannel],
        failure: String? = nil,
        deadline: Duration = .seconds(5)
    ) throws -> String? {
        var remaining: [FakeControlChannel] = channels
        return try ScrcpyClipboardExchange.read(
            serial: "R3CT312YV5B",
            deadline: .now + deadline,
            emptyGrace: .seconds(1),
            connect: { remaining.isEmpty ? nil : remaining.removeFirst() },
            serverFailure: { failure }
        )
    }

    private static func clipboard(_ text: String) -> [UInt8] {
        ScrcpyDeviceMessageTests.clipboard(text)
    }

    @Test
    func `sends get clipboard after the dummy byte and returns the text`() throws {
        let channel: FakeControlChannel = .init([Self.dummyByte, .bytes(Self.clipboard("hello"))])

        let text: String? = try Self.read([channel])

        #expect(text == "hello")
        #expect(channel.written == [[8, 0]])
    }

    @Test
    func `assembles a reply that arrives in several chunks`() throws {
        let whole: [UInt8] = Self.clipboard("héllo 🎉")
        let channel: FakeControlChannel = .init([
            Self.dummyByte,
            .bytes(Array(whole[..<2])),
            .bytes(Array(whole[2 ..< 7])),
            .bytes(Array(whole[7...]))
        ])

        #expect(try Self.read([channel]) == "héllo 🎉")
    }

    @Test
    func `silence after the request means no text`() throws {
        let channel: FakeControlChannel = .init([Self.dummyByte])

        #expect(try Self.read([channel]) == nil)
    }

    @Test
    func `a partial reply followed by silence is a timeout`() {
        let whole: [UInt8] = Self.clipboard("hello")
        let channel: FakeControlChannel = .init([Self.dummyByte, .bytes(Array(whole[..<7]))])

        #expect(throws: DeviceClipboardError.timedOut(serial: "R3CT312YV5B")) {
            try Self.read([channel])
        }
    }

    @Test
    func `a closed connection after the request reports the server's last line`() {
        let channel: FakeControlChannel = .init([Self.dummyByte, .closed])

        #expect(throws: DeviceClipboardError.failed(line: "[server] ERROR: boom")) {
            try Self.read([channel], failure: "[server] ERROR: boom")
        }
    }

    @Test
    func `a closed connection with no server line says so`() {
        let channel: FakeControlChannel = .init([Self.dummyByte, .closed])

        #expect(throws: DeviceClipboardError.failed(line: "scrcpy server closed the connection")) {
            try Self.read([channel])
        }
    }

    @Test
    func `a connection adb dropped before the server listened is retried`() throws {
        let dropped: FakeControlChannel = .init([.closed])
        let good: FakeControlChannel = .init([Self.dummyByte, .bytes(Self.clipboard("ok"))])

        #expect(try Self.read([dropped, good]) == "ok")
        #expect(dropped.written.isEmpty)
        #expect(good.written == [[8, 0]])
    }

    @Test
    func `a server that already exited fails before any connection`() {
        #expect(throws: DeviceClipboardError.failed(line: "The server version (5.0.1) does not match the client (4.0)")) {
            try Self.read([.init([Self.dummyByte])], failure: "The server version (5.0.1) does not match the client (4.0)")
        }
    }

    @Test
    func `no connection before the deadline is a timeout`() {
        #expect(throws: DeviceClipboardError.timedOut(serial: "R3CT312YV5B")) {
            try Self.read([], deadline: .milliseconds(250))
        }
    }

    @Test
    func `a channel that refuses the request fails`() {
        let channel: FakeControlChannel = .init([Self.dummyByte], acceptsWrites: false)

        #expect(throws: DeviceClipboardError.failed(line: "scrcpy server closed the connection")) {
            try Self.read([channel])
        }
    }

    @Test
    func `an unexpected message type fails with its description`() {
        let channel: FakeControlChannel = .init([Self.dummyByte, .bytes([1, 0, 0, 0, 0, 0, 0, 0, 0])])

        #expect(throws: DeviceClipboardError.failed(line: "unexpected scrcpy device message type 1")) {
            try Self.read([channel])
        }
    }
}
