import BerthCore
import Foundation
import Synchronization
import Testing

@testable import BerthDaemon

@Suite
struct AutoUpdaterTests {
    @Test
    func `installs a newer release and logs it`() async {
        let source: StubUpdateSource = .newer()
        let lines: Lines = .init()
        let updater: AutoUpdater = .init(source: source, autoUpdate: true, currentVersion: "1.0.0", log: { lines.add($0) })

        await updater.checkOnce()

        #expect(source.installs == 1)
        #expect(lines.all == ["auto update: installed 1.0.0 → 2.0.0"])
    }

    @Test
    func `logs a failure and does not install`() async {
        struct Boom: Error {}
        let source: StubUpdateSource = .init(.failure(Boom()))
        let lines: Lines = .init()
        let updater: AutoUpdater = .init(source: source, autoUpdate: true, currentVersion: "1.0.0", log: { lines.add($0) })

        await updater.checkOnce()

        #expect(source.installs == 0)
        #expect(lines.all.count == 1 && lines.all[0].hasPrefix("auto update failed:"))
    }

    @Test
    func `never checks when disabled or on a dev build`() async {
        for (enabled, version) in [(false, "1.0.0"), (true, "dev")] {
            let source: StubUpdateSource = .newer()
            let updater: AutoUpdater = .init(source: source, autoUpdate: enabled, currentVersion: version, delay: .milliseconds(1), interval: .milliseconds(1))

            await updater.run()
            await updater.checkOnce()

            #expect(source.checks == 0)
        }
    }

    @Test
    func `run checks again every interval`() async throws {
        let source: StubUpdateSource = .init(.success(.upToDate(current: .init(major: 1, minor: 0, patch: 0), latest: .init(major: 1, minor: 0, patch: 0))))
        let updater: AutoUpdater = .init(source: source, autoUpdate: true, currentVersion: "1.0.0", delay: .milliseconds(1), interval: .milliseconds(10))

        let task: Task<Void, Never> = Task { await updater.run() }
        try await eventually { source.checks >= 3 }
        task.cancel()
    }
}

private extension AutoUpdaterTests {
    final class Lines: Sendable {
        private let storage: Mutex<[String]> = .init([])

        var all: [String] { storage.withLock { $0 } }

        func add(_ line: String) { storage.withLock { $0.append(line) } }
    }
}
