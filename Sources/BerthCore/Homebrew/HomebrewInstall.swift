import Foundation

/// A berth binary installed by a Homebrew formula, reached through its version-independent `opt` path.
public struct HomebrewInstall: Sendable, Equatable {
    let stablePath: String

    /// - Parameters:
    ///   - resolvedPath: Executable path with symlinks resolved, `<prefix>/Cellar/berth/<version>/bin/<name>` under Homebrew.
    ///   - fileExists: Checks that the stable path exists.
    init?(resolvedPath: String, fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) {
        let components: [String] = URL(fileURLWithPath: resolvedPath).pathComponents
        let keg: [String] = Array(components.suffix(5))
        guard
            components.count >= 6,
            keg[0] == "Cellar",
            keg[1] == "berth",
            keg[3] == "bin",
            let name = components.last
        else {
            return nil
        }
        let prefix: String = NSString.path(withComponents: Array(components.dropLast(5)))
        let stablePath: String = "\(prefix)/opt/berth/bin/\(name)"
        guard fileExists(stablePath) else { return nil }
        self.stablePath = stablePath
    }

    public static func current() -> HomebrewInstall? {
        .init(resolvedPath: LaunchAgent.resolvedExecutablePath())
    }
}
