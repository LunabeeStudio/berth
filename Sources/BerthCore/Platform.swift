public enum Platform: String, Codable, Sendable, Hashable, CaseIterable {
    case android
    case ios

    public var deviceKind: String {
        switch self {
        case .android: "AVD"
        case .ios: "simulator"
        }
    }
}
