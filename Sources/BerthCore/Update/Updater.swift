import Foundation

/// Checks the release feed and installs a newer release beside the running executable.
public struct Updater: UpdateSource {
    public static let archiveName: String = "berth-macos-arm64.tar.gz"
    public static let defaultFeed: URL = .init(string: "https://api.github.com/repos/LunabeeStudio/berth/releases/latest")!

    private let feed: URL
    private let currentVersion: String
    private let executablePath: String

    public init(
        feed: URL = Updater.feedFromEnvironment(),
        currentVersion: String = BerthVersion.current,
        executablePath: String = LaunchAgent.currentExecutablePath()
    ) {
        self.feed = feed
        self.currentVersion = currentVersion
        self.executablePath = executablePath
    }

    public static func feedFromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        environment["BERTH_UPDATE_URL"].flatMap { URL(string: $0) } ?? defaultFeed
    }

    /// - Throws: `UpdateError.devBuild` for a `dev` build, `UpdateError.invalidTag` when the feed tag is not `X.Y.Z`, or a network or decoding error.
    public func check() async throws -> UpdateCheck {
        guard let current = SemanticVersion(currentVersion) else { throw UpdateError.devBuild }
        let data: Data = try await Download.data(from: feed)
        let decoder: JSONDecoder = .init()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release: Release = try decoder.decode(Release.self, from: data)
        guard let latest = release.version else { throw UpdateError.invalidTag(release.tagName) }
        return latest > current
            ? .available(current: current, latest: latest, release: release)
            : .upToDate(current: current, latest: latest)
    }

    /// Replaces `berth`, and `berth-bar` when it sits beside it, with the release contents. Nothing is replaced on failure.
    public func install(_ release: Release) async throws {
        try await Installer(executablePath: executablePath).install(release)
    }
}
