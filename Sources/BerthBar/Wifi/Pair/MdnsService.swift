struct MdnsService: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case pairing
        case connect
    }

    let name: String
    let kind: Kind
    let address: String

    var host: String { Self.host(ofAddress: address) }

    static func host(ofAddress address: String) -> String {
        String(address.prefix { $0 != ":" })
    }
}
