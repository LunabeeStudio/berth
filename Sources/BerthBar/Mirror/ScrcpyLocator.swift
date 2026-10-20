import Foundation

struct ScrcpyLocator {
    private let environment: [String: String]
    private let fallbackDirectories: [String]

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fallbackDirectories: [String] = ["/opt/homebrew/bin", "/usr/local/bin"]
    ) {
        self.environment = environment
        self.fallbackDirectories = fallbackDirectories
    }

    func locate() -> String? {
        let pathDirectories: [String] = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        return (pathDirectories + fallbackDirectories)
            .map { URL(fileURLWithPath: $0).appending(path: "scrcpy").path }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
