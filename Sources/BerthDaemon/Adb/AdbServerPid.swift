import BerthCore
import Foundation

enum AdbServerPid {
    static let defaultPort: Int = 5037

    /// Only observes: never starts or stops the adb server.
    static func sample() async -> Int32? {
        let port: Int = ProcessInfo.processInfo.environment["ANDROID_ADB_SERVER_PORT"].flatMap { Int($0) } ?? defaultPort
        let arguments: [String] = ["-nP", "-t", "-iTCP:\(port)", "-sTCP:LISTEN"]
        guard let result = try? await Shell.run("/usr/sbin/lsof", arguments, timeout: .seconds(5)), result.succeeded else { return nil }
        return result.trimmedOutput.split(whereSeparator: \.isNewline).first.flatMap { Int32($0) }
    }
}
