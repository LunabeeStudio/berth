import Foundation

enum ScrcpyClipboardExchange {
    private static let serverCheckInterval: Duration = .milliseconds(200)
    private static let retryInterval: TimeInterval = 0.1

    /// The server sends no reply for an empty or non-text clipboard, so silence for `emptyGrace` means "no text".
    static func read(
        serial: String,
        deadline: ContinuousClock.Instant,
        emptyGrace: Duration = .seconds(3),
        connect: () -> (any ScrcpyControlChannel)?,
        serverFailure: () -> String?
    ) throws -> String? {
        let channel: any ScrcpyControlChannel = try open(serial: serial, deadline: deadline, connect: connect, serverFailure: serverFailure)
        guard channel.write(ScrcpyControlMessage.getClipboard.bytes) else {
            throw DeviceClipboardError.failed(line: serverFailure() ?? "scrcpy server closed the connection")
        }
        return try awaitClipboard(on: channel, serial: serial, deadline: deadline, emptyGrace: emptyGrace, serverFailure: serverFailure)
    }

    /// The server accepts one control connection only: an open one is kept and waited on, a closed one is retried
    /// (adb accepts before the server listens, then drops it).
    private static func open(
        serial: String,
        deadline: ContinuousClock.Instant,
        connect: () -> (any ScrcpyControlChannel)?,
        serverFailure: () -> String?
    ) throws -> any ScrcpyControlChannel {
        while ContinuousClock.now < deadline {
            if let line = serverFailure() { throw DeviceClipboardError.failed(line: line) }
            if let channel = connect(), try awaitDummyByte(on: channel, deadline: deadline, serverFailure: serverFailure) {
                return channel
            }
            Thread.sleep(forTimeInterval: retryInterval)
        }
        throw DeviceClipboardError.timedOut(serial: serial)
    }

    private static func awaitDummyByte(
        on channel: any ScrcpyControlChannel,
        deadline: ContinuousClock.Instant,
        serverFailure: () -> String?
    ) throws -> Bool {
        while ContinuousClock.now < deadline {
            switch channel.read(until: min(deadline, .now + serverCheckInterval)) {
            case .bytes: return true
            case .closed: return false
            case .timeout:
                if let line = serverFailure() { throw DeviceClipboardError.failed(line: line) }
            }
        }
        return false
    }

    private static func awaitClipboard(
        on channel: any ScrcpyControlChannel,
        serial: String,
        deadline: ContinuousClock.Instant,
        emptyGrace: Duration,
        serverFailure: () -> String?
    ) throws -> String? {
        var buffer: [UInt8] = []
        var waitUntil: ContinuousClock.Instant = min(deadline, .now + emptyGrace)
        while true {
            switch channel.read(until: waitUntil) {
            case let .bytes(chunk):
                buffer += chunk
                if let message = try decode(buffer) {
                    switch message {
                    case let .clipboard(text): return text
                    }
                }
                waitUntil = deadline
            case .timeout:
                guard buffer.isEmpty, ContinuousClock.now < deadline else { throw DeviceClipboardError.timedOut(serial: serial) }
                return nil
            case .closed:
                throw DeviceClipboardError.failed(line: serverFailure() ?? "scrcpy server closed the connection")
            }
        }
    }

    private static func decode(_ buffer: [UInt8]) throws -> ScrcpyDeviceMessage? {
        do {
            return try ScrcpyDeviceMessage.decode(buffer)
        } catch {
            throw DeviceClipboardError.failed(line: "\(error)")
        }
    }
}
