import Foundation

public enum Paths {
    public static let home: URL = {
        if let custom = ProcessInfo.processInfo.environment["BERTH_HOME"], !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/berth", directoryHint: .isDirectory)
    }()

    public static let logs: URL = {
        if ProcessInfo.processInfo.environment["BERTH_HOME"] != nil {
            return home.appending(path: "logs", directoryHint: .isDirectory)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Logs/berth", directoryHint: .isDirectory)
    }()

    public static var socket: URL { home.appending(path: "berth.sock") }
    public static var config: URL { home.appending(path: "config.json") }
    public static var state: URL { home.appending(path: "state.json") }
    public static var lock: URL { home.appending(path: "daemon.lock") }
    public static var daemonLog: URL { logs.appending(path: "daemon.log") }

    public static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
    }
}
