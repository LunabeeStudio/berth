import Foundation

/// After a usbmuxd `Connect` the socket is a raw tunnel to lockdownd: each message is a 4-byte big-endian length followed by an XML plist.
enum LockdownFraming {
    private static let maxLength: Int = 1 << 20

    static func frame(_ payload: Data) -> Data {
        withUnsafeBytes(of: UInt32(payload.count).bigEndian) { Data($0) } + payload
    }

    static func send(_ payload: Data, over connection: any UsbmuxConnection) throws {
        try connection.send(frame(payload))
    }

    static func receive(from connection: any UsbmuxConnection) throws -> Data {
        let header: Data = try connection.receive(count: 4)
        let length: Int = Int(header.reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        guard length <= maxLength else { throw UsbmuxError.malformedReply }
        return try connection.receive(count: length)
    }
}
