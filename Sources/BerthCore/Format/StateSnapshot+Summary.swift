import Foundation

extension StateSnapshot {
    public var summary: String {
        "\(slots.count)/\(maxRunning) running · \(queue.count) waiting"
    }

    public func adbNotice(now: Date) -> String? {
        AdbInstability.notice(restartedAt: adbRestartedAt, now: now)
    }
}
