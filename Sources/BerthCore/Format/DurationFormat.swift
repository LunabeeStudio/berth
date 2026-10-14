import Foundation

public enum DurationFormat {
    public static func clock(_ interval: TimeInterval) -> String {
        let total: Int = max(0, Int(interval))
        let (hours, minutes, seconds): (Int, Int, Int) = (total / 3600, total / 60 % 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    public static func remaining(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "expired" }
        let minutes: Int = Int(interval) / 60
        return minutes >= 60 ? "\(minutes / 60)h\(String(format: "%02d", minutes % 60))" : "\(minutes)m"
    }
}
