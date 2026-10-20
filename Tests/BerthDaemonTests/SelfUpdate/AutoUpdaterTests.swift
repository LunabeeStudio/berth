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
        let lines: LockedLines = .init()
        let updater: AutoUpdater = .init(source: source, isAutoUpdateEnabled: { true }, currentVersion: "1.0.0", log: { lines.add($0) })

        await updater.checkOnce()

        #expect(source.installs == 1)
        #expect(lines.all == ["auto update: installed 1.0.0 → 2.0.0"])
    }

    @Test
    func `logs a failure and does not install`() async {
        struct Boom: Error {}
        let source: StubUpdateSource = .init(.failure(Boom()))
        let lines: LockedLines = .init()
        let updater: AutoUpdater = .init(source: source, isAutoUpdateEnabled: { true }, currentVersion: "1.0.0", log: { lines.add($0) })

        await updater.checkOnce()

        #expect(source.installs == 0)
        #expect(lines.all.count == 1 && lines.all[0].hasPrefix("auto update failed:"))
    }

    @Test
    func `never checks when disabled or on a dev build`() async {
        for (enabled, version) in [(false, "1.0.0"), (true, "dev")] {
            let source: StubUpdateSource = .newer()
            let updater: AutoUpdater = .init(source: source, isAutoUpdateEnabled: { enabled }, currentVersion: version, delay: .milliseconds(1), interval: .milliseconds(1))

            await updater.checkOnce()

            #expect(source.checks == 0)
        }
    }

    @Test
    func `run returns at once on a dev build whatever the setting`() async {
        let source: StubUpdateSource = .newer()
        let updater: AutoUpdater = .init(source: source, isAutoUpdateEnabled: { true }, currentVersion: "dev", delay: .milliseconds(1), interval: .milliseconds(1))

        await updater.run()

        #expect(source.checks == 0)
    }

    @Test
    func `run starts checking once the setting is turned on`() async throws {
        let source: StubUpdateSource = .newer()
        let enabled: Mutex<Bool> = .init(false)
        let updater: AutoUpdater = .init(source: source, isAutoUpdateEnabled: { enabled.withLock { $0 } }, currentVersion: "1.0.0", delay: .milliseconds(1), interval: .milliseconds(10))

        let task: Task<Void, Never> = Task { await updater.run() }
        try await Task.sleep(for: .milliseconds(60))
        #expect(source.checks == 0)
        #expect(source.installs == 0)

        enabled.withLock { $0 = true }
        try await eventually { source.installs >= 1 }
        task.cancel()
    }

    @Test
    func `run stops checking once the setting is turned off`() async throws {
        let source: StubUpdateSource = .upToDate()
        let enabled: Mutex<Bool> = .init(true)
        let updater: AutoUpdater = .init(source: source, isAutoUpdateEnabled: { enabled.withLock { $0 } }, currentVersion: "1.0.0", delay: .milliseconds(1), interval: .milliseconds(10))

        let task: Task<Void, Never> = Task { await updater.run() }
        try await eventually { source.checks >= 2 }
        enabled.withLock { $0 = false }
        try await Task.sleep(for: .milliseconds(30))
        let frozen: Int = source.checks
        try await Task.sleep(for: .milliseconds(60))
        task.cancel()

        #expect(source.checks == frozen)
    }

    @Test
    func `run checks again every interval`() async throws {
        let source: StubUpdateSource = .init(.success(.upToDate(current: .init(major: 1, minor: 0, patch: 0), latest: .init(major: 1, minor: 0, patch: 0))))
        let updater: AutoUpdater = .init(source: source, isAutoUpdateEnabled: { true }, currentVersion: "1.0.0", delay: .milliseconds(1), interval: .milliseconds(10))

        let task: Task<Void, Never> = Task { await updater.run() }
        try await eventually { source.checks >= 3 }
        task.cancel()
    }
}
