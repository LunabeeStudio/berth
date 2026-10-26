import BerthCore
import Foundation
import Testing

@testable import BerthDaemon

@Suite
struct BrokerAdbRestartTests {
    private static let notice: String = "adb unstable: server restarted 0 s ago; devices reconnect on their own, keep your lease"

    private func restart(_ harness: Harness, from old: Int32 = 100, to new: Int32 = 200) async {
        harness.adbPid.value = old
        await harness.broker.reap()
        harness.adbPid.value = new
        await harness.broker.reap()
    }

    @Test
    func `an iOS-only pool never samples adb`() async {
        let harness: Harness = .init(pool: [PoolEntry(name: "iPhone 17", platform: .ios, maxInstances: 1)])
        harness.adbPid.value = 100

        await harness.broker.reap()
        harness.adbPid.value = 200
        await harness.broker.reap()

        #expect(harness.adbPid.reads == 0)
        #expect(await harness.broker.snapshot().adbRestartedAt == nil)
    }

    @Test
    func `baseline pid leaves the snapshot clean`() async {
        let harness: Harness = .init()
        harness.adbPid.value = 100

        await harness.broker.reap()

        #expect(await harness.broker.snapshot().adbRestartedAt == nil)
    }

    @Test
    func `a restart stamps the snapshot`() async {
        let harness: Harness = .init()

        await restart(harness)

        let snapshot: StateSnapshot = await harness.broker.snapshot()
        #expect(snapshot.adbRestartedAt == harness.clock.now)
        #expect(snapshot.adbNotice(now: harness.clock.now) == Self.notice)
    }

    @Test
    func `the stamp is carried for 59 s and gone at 60 s`() async {
        let harness: Harness = .init()
        await restart(harness)

        harness.clock.advance(59)
        #expect(await harness.broker.snapshot().adbRestartedAt != nil)

        harness.clock.advance(1)
        #expect(await harness.broker.snapshot().adbRestartedAt == nil)
    }

    @Test
    func `a claim arriving while unstable gets the notice`() async throws {
        let harness: Harness = .init()
        await restart(harness)

        let client: Client = await harness.claim()

        try await eventually { client.notices == [Self.notice] }
    }

    @Test
    func `a claim arriving on a stable adb gets no notice`() async throws {
        let harness: Harness = .init()
        harness.adbPid.value = 100
        await harness.broker.reap()

        let client: Client = await harness.claim()
        try await eventually { client.grant != nil }

        #expect(client.notices.isEmpty)
    }

    @Test
    func `a waiter gets the notice when a restart is seen`() async throws {
        let harness: Harness = .init(maxRunning: 1, pool: [PoolEntry(name: "Pixel", maxInstances: 1)])
        harness.adbPid.value = 100
        await harness.broker.reap()
        await harness.claim(pid: 100)
        let waiter: Client = await harness.claim(pid: 101)
        try await eventually { waiter.lastPosition != nil }

        harness.adbPid.value = 200
        await harness.broker.reap()

        try await eventually { waiter.notices == [Self.notice] }
    }
}
