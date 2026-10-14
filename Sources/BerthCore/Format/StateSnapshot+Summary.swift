extension StateSnapshot {
    public var summary: String {
        "\(slots.count)/\(maxRunning) running · \(queue.count) waiting"
    }
}
