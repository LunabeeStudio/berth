extension Array where Element == PoolEntry {
    public func entry(for model: String) -> PoolEntry? {
        first { $0.name == model }
    }

    public func platform(of model: String) -> Platform {
        entry(for: model)?.platform ?? .android
    }
}
