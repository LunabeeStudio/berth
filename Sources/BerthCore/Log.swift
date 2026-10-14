import Foundation

public enum Log {
    public static func info(_ message: String) {
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
        FileHandle.standardError.write(Data("[\(stamp)] \(message)\n".utf8))
    }
}
