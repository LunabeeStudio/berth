import Foundation

public struct ScrcpyServerLocator: Sendable {
    public static let environmentKey: String = "SCRCPY_SERVER_PATH"

    private let environment: [String: String]
    private let fileExists: @Sendable (String) -> Bool

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileExists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) {
        self.environment = environment
        self.fileExists = fileExists
    }

    public func locate(scrcpyPath: String) -> String? {
        if let override = environment[Self.environmentKey], !override.isEmpty {
            return fileExists(override) ? override : nil
        }
        let binary: URL = .init(fileURLWithPath: scrcpyPath)
        return [binary, binary.resolvingSymlinksInPath()]
            .map { $0.deletingLastPathComponent().deletingLastPathComponent().appending(path: "share/scrcpy/scrcpy-server").path }
            .first(where: fileExists)
    }
}
