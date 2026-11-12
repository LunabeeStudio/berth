public struct AVD: Sendable, Hashable {
    public let name: String
    public let prepared: Bool

    public init(name: String, prepared: Bool) {
        self.name = name
        self.prepared = prepared
    }
}
