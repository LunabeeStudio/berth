import Foundation

public struct LaunchAgent: Sendable {
    public let label: String
    private let directory: URL

    public var plist: URL { directory.appending(path: "\(label).plist") }
    public var isInstalled: Bool { FileManager.default.fileExists(atPath: plist.path) }
    public var domain: String { "gui/\(getuid())" }

    public init(
        label: String,
        directory: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/LaunchAgents", directoryHint: .isDirectory)
    ) {
        self.label = label
        self.directory = directory
    }

    public static func currentExecutablePath() -> String {
        URL(fileURLWithPath: Bundle.main.executablePath ?? CommandLine.arguments[0]).resolvingSymlinksInPath().path
    }

    public func write(_ contents: [String: Any]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: contents, format: .xml, options: 0).write(to: plist)
    }

    public func remove() throws {
        guard isInstalled else { return }
        try FileManager.default.removeItem(at: plist)
    }
}
