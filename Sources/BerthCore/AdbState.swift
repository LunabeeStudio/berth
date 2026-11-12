public enum AdbState: Codable, Sendable, Hashable {
    case device
    case unauthorized
    case offline
    case other(String)

    public var word: String {
        switch self {
        case .device: "device"
        case .unauthorized: "unauthorized"
        case .offline: "offline"
        case let .other(word): word
        }
    }

    public init(word: String) {
        switch word {
        case "device": self = .device
        case "unauthorized": self = .unauthorized
        case "offline": self = .offline
        default: self = .other(word)
        }
    }

    public init(from decoder: any Decoder) throws {
        self.init(word: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container: any SingleValueEncodingContainer = encoder.singleValueContainer()
        try container.encode(word)
    }
}
