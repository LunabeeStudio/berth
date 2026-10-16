import Foundation
import Testing

@testable import BerthCore

@Suite
struct UpdaterTests {
    @Test
    func `newer release is available`() async throws {
        let fixture: UpdateFixture = try await .init(tag: "v0.2.0")
        defer { fixture.cleanUp() }

        let check: UpdateCheck = try await fixture.updater(current: "0.1.0").check()

        guard case let .available(current, latest, _) = check else {
            Issue.record("expected available, got \(check)")
            return
        }
        #expect(current.description == "0.1.0")
        #expect(latest.description == "0.2.0")
    }

    @Test
    func `same or older release is up to date`() async throws {
        let fixture: UpdateFixture = try await .init(tag: "v0.2.0")
        defer { fixture.cleanUp() }

        for current in ["0.2.0", "0.3.0"] {
            let check: UpdateCheck = try await fixture.updater(current: current).check()
            guard case .upToDate = check else {
                Issue.record("expected upToDate for \(current), got \(check)")
                return
            }
        }
    }

    @Test
    func `dev build is never updatable`() async throws {
        let fixture: UpdateFixture = try await .init(tag: "v9.9.9")
        defer { fixture.cleanUp() }

        await #expect(throws: UpdateError.devBuild) {
            try await fixture.updater(current: "dev").check()
        }
    }

    @Test
    func `install replaces berth and the berth-bar beside it`() async throws {
        let fixture: UpdateFixture = try await .init(tag: "v0.2.0")
        defer { fixture.cleanUp() }
        let updater: Updater = fixture.updater(current: "0.1.0")
        guard case let .available(_, _, release) = try await updater.check() else {
            Issue.record("expected available")
            return
        }

        try await updater.install(release)

        #expect(try fixture.read(fixture.berth) == "new berth")
        #expect(try fixture.read(fixture.berthBar) == "new bar")
        let mode: Int? = try FileManager.default.attributesOfItem(atPath: fixture.berth.path)[.posixPermissions] as? Int
        #expect(mode == 0o755)
        let leftovers: [String] = try FileManager.default.contentsOfDirectory(atPath: fixture.installDirectory.path)
        #expect(leftovers.sorted() == ["berth", "berth-bar"])
    }

    @Test
    func `install skips berth-bar when absent`() async throws {
        let fixture: UpdateFixture = try await .init(tag: "v0.2.0", withBar: false)
        defer { fixture.cleanUp() }
        let updater: Updater = fixture.updater(current: "0.1.0")
        guard case let .available(_, _, release) = try await updater.check() else {
            Issue.record("expected available")
            return
        }

        try await updater.install(release)

        #expect(try fixture.read(fixture.berth) == "new berth")
        #expect(!FileManager.default.fileExists(atPath: fixture.berthBar.path))
    }

    @Test
    func `checksum mismatch leaves files untouched and cleans up`() async throws {
        let fixture: UpdateFixture = try await .init(tag: "v0.2.0", corruptChecksum: true)
        defer { fixture.cleanUp() }
        let updater: Updater = fixture.updater(current: "0.1.0")
        guard case let .available(_, _, release) = try await updater.check() else {
            Issue.record("expected available")
            return
        }

        await #expect(throws: UpdateError.self) {
            try await updater.install(release)
        }

        #expect(try fixture.read(fixture.berth) == "old berth")
        #expect(try fixture.read(fixture.berthBar) == "old bar")
        let leftovers: [String] = try FileManager.default.contentsOfDirectory(atPath: fixture.installDirectory.path)
        #expect(leftovers.sorted() == ["berth", "berth-bar"])
    }

    @Test
    func `read-only install directory fails naming the directory`() async throws {
        let fixture: UpdateFixture = try await .init(tag: "v0.2.0")
        defer { fixture.cleanUp() }
        let updater: Updater = fixture.updater(current: "0.1.0")
        guard case let .available(_, _, release) = try await updater.check() else {
            Issue.record("expected available")
            return
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: fixture.installDirectory.path)

        await #expect(throws: UpdateError.notWritable(fixture.installDirectory.path)) {
            try await updater.install(release)
        }
        #expect(try fixture.read(fixture.berth) == "old berth")
    }
}
