import Testing

@testable import BerthCore

@Suite
struct HomebrewInstallTests {
    @Test(arguments: ["/opt/homebrew", "/usr/local", "/Users/ada/brew"], ["berth", "berth-bar"])
    func `keg path is a homebrew install with the opt path`(prefix: String, name: String) throws {
        let stablePath: String = "\(prefix)/opt/berth/bin/\(name)"

        let install: HomebrewInstall = try #require(
            HomebrewInstall(resolvedPath: "\(prefix)/Cellar/berth/0.6.0/bin/\(name)", fileExists: { $0 == stablePath })
        )

        #expect(install.stablePath == stablePath)
    }

    @Test(arguments: [
        "/Users/ada/.local/bin/berth",
        "/Users/ada/dev/berth/.build/arm64-apple-macosx/debug/berth",
        "/opt/homebrew/Cellar/other/1.0/bin/berth",
        "/opt/homebrew/Cellar/berth/0.6.0/libexec/berth"
    ])
    func `other paths are direct installs`(path: String) {
        #expect(HomebrewInstall(resolvedPath: path, fileExists: { _ in true }) == nil)
    }

    @Test
    func `keg path without its opt file is a direct install`() {
        #expect(HomebrewInstall(resolvedPath: "/opt/homebrew/Cellar/berth/0.6.0/bin/berth", fileExists: { _ in false }) == nil)
    }
}
