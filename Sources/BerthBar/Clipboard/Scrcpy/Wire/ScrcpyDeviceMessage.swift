enum ScrcpyDeviceMessage: Equatable {
    case clipboard(String)

    enum DecodingError: Error, CustomStringConvertible, Equatable {
        case unknownType(UInt8)
        case textTooLong(Int)

        var description: String {
            switch self {
            case let .unknownType(type): "unexpected scrcpy device message type \(type)"
            case let .textTooLong(length): "scrcpy clipboard message of \(length) bytes exceeds the protocol limit"
            }
        }
    }

    private static let clipboardType: UInt8 = 0
    private static let headerLength: Int = 5
    private static let maxTextLength: Int = (1 << 18) - headerLength

    /// - Returns: the first message in `bytes`, or nil while `bytes` holds only part of it.
    static func decode(_ bytes: [UInt8]) throws -> ScrcpyDeviceMessage? {
        guard let type = bytes.first else { return nil }
        guard type == clipboardType else { throw DecodingError.unknownType(type) }
        guard bytes.count >= headerLength else { return nil }
        let length: Int = bytes[1 ..< headerLength].reduce(0) { $0 << 8 | Int($1) }
        guard length <= maxTextLength else { throw DecodingError.textTooLong(length) }
        guard bytes.count >= headerLength + length else { return nil }
        let text: String = .init(decoding: bytes[headerLength ..< headerLength + length], as: UTF8.self)
        return .clipboard(text)
    }
}
