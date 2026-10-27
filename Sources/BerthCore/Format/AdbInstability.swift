import Foundation

public enum AdbInstability {
    public static let window: TimeInterval = 60

    public static func isUnstable(restartedAt: Date?, now: Date) -> Bool {
        guard let restartedAt else { return false }
        let age: TimeInterval = now.timeIntervalSince(restartedAt)
        return age >= 0 && age < window
    }

    public static func notice(restartedAt: Date?, now: Date) -> String? {
        guard let restartedAt, isUnstable(restartedAt: restartedAt, now: now) else { return nil }
        return "adb unstable: server restarted \(Int(now.timeIntervalSince(restartedAt))) s ago; devices reconnect on their own, keep your lease"
    }
}
