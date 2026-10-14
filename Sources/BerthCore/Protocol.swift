import Foundation
import NIOCore

public struct ClaimRequest: Codable, Sendable {
    public var model: String?
    public var platform: Platform?
    public var ttl: Int?
    public var label: String?
    public var owner: Owner

    public init(model: String?, platform: Platform? = nil, ttl: Int?, label: String?, owner: Owner) {
        self.model = model
        self.platform = platform
        self.ttl = ttl
        self.label = label
        self.owner = owner
    }

    public var resolvedPlatform: Platform { platform ?? .android }
}

public enum Request: Codable, Sendable {
    case claim(ClaimRequest)
    case ack(lease: String)
    case release(target: String)
    case renew(target: String, ttl: Int?)
    case stop(target: String)
    case stopAll
    case status
    case watch
    case shutdown
}

public enum Event: Codable, Sendable {
    case queued(position: Int)
    case granted(Grant)
    case ok(String)
    case failure(String)
    case state(StateSnapshot)
}

public enum Wire {
    public static func encoder(pretty: Bool = false) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    public static func line<T: Encodable>(_ value: T) throws -> ByteBuffer {
        var data = try encoder().encode(value)
        data.append(0x0A)
        return ByteBuffer(bytes: data)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from buffer: ByteBuffer) throws -> T {
        try decoder().decode(type, from: Data(buffer.readableBytesView))
    }

    public static func json<T: Encodable>(_ value: T) -> String {
        let data = (try? encoder(pretty: true).encode(value)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}

public struct NewlineFrameDecoder: ByteToMessageDecoder {
    public typealias InboundOut = ByteBuffer

    static let maxLineLength = 4 * 1024 * 1024

    public init() {}

    public mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        guard let newline = buffer.readableBytesView.firstIndex(of: UInt8(ascii: "\n")) else {
            if buffer.readableBytes > Self.maxLineLength { throw ByteToMessageDecoderError.PayloadTooLargeError() }
            return .needMoreData
        }
        let line = buffer.readSlice(length: newline - buffer.readerIndex)!
        buffer.moveReaderIndex(forwardBy: 1)
        context.fireChannelRead(wrapInboundOut(line))
        return .continue
    }

    public mutating func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        while try decode(context: context, buffer: &buffer) == .continue {}
        return .needMoreData
    }
}
