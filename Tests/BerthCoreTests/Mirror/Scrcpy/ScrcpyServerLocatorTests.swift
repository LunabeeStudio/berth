import Foundation
import Testing

@testable import BerthCore

@Suite
struct ScrcpyServerLocatorTests {
    @Test
    func `the environment override wins when the file exists`() {
        let locator: ScrcpyServerLocator = .init(
            environment: ["SCRCPY_SERVER_PATH": "/custom/server"],
            fileExists: { _ in true }
        )

        #expect(locator.locate(scrcpyPath: "/opt/homebrew/bin/scrcpy") == "/custom/server")
    }

    @Test
    func `a missing override file finds nothing, without falling back`() {
        let locator: ScrcpyServerLocator = .init(
            environment: ["SCRCPY_SERVER_PATH": "/custom/server"],
            fileExists: { $0 == "/opt/homebrew/share/scrcpy/scrcpy-server" }
        )

        #expect(locator.locate(scrcpyPath: "/opt/homebrew/bin/scrcpy") == nil)
    }

    @Test
    func `an empty override is ignored`() {
        let locator: ScrcpyServerLocator = .init(
            environment: ["SCRCPY_SERVER_PATH": ""],
            fileExists: { $0 == "/opt/homebrew/share/scrcpy/scrcpy-server" }
        )

        #expect(locator.locate(scrcpyPath: "/opt/homebrew/bin/scrcpy") == "/opt/homebrew/share/scrcpy/scrcpy-server")
    }

    @Test
    func `without override the server sits in share next to the binary directory`() {
        let locator: ScrcpyServerLocator = .init(
            environment: [:],
            fileExists: { $0 == "/usr/local/share/scrcpy/scrcpy-server" }
        )

        #expect(locator.locate(scrcpyPath: "/usr/local/bin/scrcpy") == "/usr/local/share/scrcpy/scrcpy-server")
    }

    @Test
    func `finds nothing when no candidate exists`() {
        let locator: ScrcpyServerLocator = .init(environment: [:], fileExists: { _ in false })

        #expect(locator.locate(scrcpyPath: "/usr/local/bin/scrcpy") == nil)
    }

    @Test
    func `follows a symlinked binary to the install that holds the server`() throws {
        let root: URL = FileManager.default.temporaryDirectory.appending(path: "berth-server-\(UUID().uuidString)")
        let cellar: URL = root.appending(path: "cellar")
        let server: URL = cellar.appending(path: "share/scrcpy/scrcpy-server")
        try FileManager.default.createDirectory(at: server.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cellar.appending(path: "bin"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appending(path: "link"), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: server.path, contents: Data())
        FileManager.default.createFile(atPath: cellar.appending(path: "bin/scrcpy").path, contents: Data())
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "link/scrcpy"),
            withDestinationURL: cellar.appending(path: "bin/scrcpy")
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let locator: ScrcpyServerLocator = .init(environment: [:])

        let located: String? = locator.locate(scrcpyPath: root.appending(path: "link/scrcpy").path)

        #expect(located.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path } == server.resolvingSymlinksInPath().path)
    }
}
