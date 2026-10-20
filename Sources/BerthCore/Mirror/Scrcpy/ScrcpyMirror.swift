import Foundation

public enum ScrcpyMirror {
    public static let notFoundMessage: String = "scrcpy not found: brew install scrcpy"

    public static func logURL(serial: String, in logs: URL) -> URL {
        logs.appending(path: "mirror-\(serial).log")
    }

    public static func prepareLogDirectory(of log: URL) throws {
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
    }
}
