struct AdbRestartDetector {
    struct Restart: Equatable {
        let old: Int32
        let new: Int32
    }

    private var lastPid: Int32?

    mutating func observe(_ pid: Int32?) -> Restart? {
        guard let pid else { return nil }
        defer { lastPid = pid }
        guard let lastPid, lastPid != pid else { return nil }
        return .init(old: lastPid, new: pid)
    }
}
