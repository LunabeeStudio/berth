enum MenuBarLabel {
    static func text(for state: StatusState) -> String? {
        guard case let .live(snapshot) = state else { return nil }
        let leased: Int = snapshot.slots.filter { $0.state == .leased }.count
        let base: String = "\(leased)/\(snapshot.slots.count)"
        return snapshot.queue.isEmpty ? base : "\(base) +\(snapshot.queue.count)"
    }

    static func symbolName(for state: StatusState) -> String {
        if case .live = state { "iphone" } else { "iphone.slash" }
    }
}
