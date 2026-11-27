enum ScrcpyControlMessage: Equatable {
    private static let getClipboardType: UInt8 = 8
    private static let copyKeyNone: UInt8 = 0

    case getClipboard

    var bytes: [UInt8] {
        switch self {
        case .getClipboard: [Self.getClipboardType, Self.copyKeyNone]
        }
    }
}
