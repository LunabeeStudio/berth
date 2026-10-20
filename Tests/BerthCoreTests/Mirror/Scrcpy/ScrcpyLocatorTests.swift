import Foundation
import Testing

@testable import BerthCore

@Suite
struct ScrcpyLocatorTests {
    @Test
    func `finds scrcpy in the first directory that holds it`() throws {
        let empty: URL = try Self.makeDirectory(withScrcpy: false)
        let first: URL = try Self.makeDirectory(withScrcpy: true)
        let second: URL = try Self.makeDirectory(withScrcpy: true)
        let locator: ScrcpyLocator = .init(environment: ["PATH": "\(empty.path):\(first.path)"], fallbackDirectories: [second.path])

        #expect(locator.locate() == first.appending(path: "scrcpy").path)
    }

    @Test
    func `falls back to the search directories when PATH has none`() throws {
        let fallback: URL = try Self.makeDirectory(withScrcpy: true)
        let locator: ScrcpyLocator = .init(environment: ["PATH": "/nonexistent"], fallbackDirectories: [fallback.path])

        #expect(locator.locate() == fallback.appending(path: "scrcpy").path)
    }

    @Test
    func `returns nil when no directory holds scrcpy`() throws {
        let empty: URL = try Self.makeDirectory(withScrcpy: false)
        let locator: ScrcpyLocator = .init(environment: [:], fallbackDirectories: [empty.path])

        #expect(locator.locate() == nil)
    }

    @Test
    func `ignores a scrcpy that is not executable`() throws {
        let directory: URL = try Self.makeDirectory(withScrcpy: false)
        FileManager.default.createFile(atPath: directory.appending(path: "scrcpy").path, contents: Data(), attributes: [.posixPermissions: 0o644])
        let locator: ScrcpyLocator = .init(environment: [:], fallbackDirectories: [directory.path])

        #expect(locator.locate() == nil)
    }

    private static func makeDirectory(withScrcpy: Bool) throws -> URL {
        let directory: URL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if withScrcpy {
            FileManager.default.createFile(atPath: directory.appending(path: "scrcpy").path, contents: Data(), attributes: [.posixPermissions: 0o755])
        }
        return directory
    }
}
