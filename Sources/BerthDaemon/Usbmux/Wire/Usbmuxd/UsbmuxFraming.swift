import Foundation

/// A usbmuxd message is a 16-byte little-endian header (total length, protocol version 1, message type 8 = plist, tag) followed by an XML plist.
enum UsbmuxFraming {
    private static let headerSize: Int = 16
    private static let version: UInt32 = 1
    private static let plistMessageType: UInt32 = 8
    private static let maxLength: Int = 1 << 20

    static func frame(_ payload: Data, tag: UInt32 = 1) -> Data {
        var frame: Data = .init()
        for field: UInt32 in [UInt32(headerSize + payload.count), version, plistMessageType, tag] {
            withUnsafeBytes(of: field.littleEndian) { frame.append(contentsOf: $0) }
        }
        return frame + payload
    }

    static func send(_ payload: Data, over connection: any UsbmuxConnection) throws {
        try connection.send(frame(payload))
    }

    static func receive(from connection: any UsbmuxConnection) throws -> Data {
        let header: Data = try connection.receive(count: headerSize)
        let length: Int = Int(header.prefix(4).reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        guard (headerSize...maxLength).contains(length) else { throw UsbmuxError.malformedReply }
        return try connection.receive(count: length - headerSize)
    }
}
