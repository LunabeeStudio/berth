import BerthCore
@testable import BerthDaemon
import Foundation
import Testing

@Suite struct BrokerTests {
    @Test func bootsOnDemandAndGrants() async throws {
        let h = Harness()
        let client = await h.claim()
        try await eventually { client.grant != nil }
        #expect(client.grant?.serial == "emulator-5554")
        #expect(await h.slots().map(\.state) == [.leased])
    }

    @Test func queuesWhenFullAndServesInFIFOOrder() async throws {
        let h = Harness(maxRunning: 1)
        let first = await h.claim(pid: 1)
        try await eventually { first.grant != nil }
        let second = await h.claim(pid: 2)
        let third = await h.claim(pid: 3)
        try await eventually { second.lastPosition == 1 && third.lastPosition == 2 }

        _ = await h.broker.release("emulator-5554")
        try await eventually { second.grant != nil }
        #expect(third.grant == nil)
        try await eventually { third.lastPosition == 1 }
        #expect(h.backend.resets == ["emulator-5554"])
    }

    @Test func waiterForBusyModelDoesNotBlockOthers() async throws {
        let h = Harness(maxRunning: 1, pool: [PoolEntry(name: "A", maxInstances: 1), PoolEntry(name: "B", maxInstances: 1)])
        let holder = await h.claim(model: "A", pid: 1)
        try await eventually { holder.grant != nil }
        let wantsB = await h.claim(model: "B", pid: 2)
        let wantsAny = await h.claim(pid: 3)

        _ = await h.broker.release("emulator-5554")
        try await eventually { wantsAny.grant != nil }
        #expect(wantsAny.grant?.model == "A")
        #expect(wantsB.grant == nil)
    }

    @Test func evictsIdleSlotOfAnotherModel() async throws {
        let h = Harness(maxRunning: 1, pool: [PoolEntry(name: "A", maxInstances: 1), PoolEntry(name: "B", maxInstances: 1)])
        let first = await h.claim(model: "A", pid: 1)
        try await eventually { first.grant != nil }
        _ = await h.broker.release(first.grant!.serial)
        try await eventually { await h.slots().first?.state == .free }

        let wantsB = await h.claim(model: "B", pid: 2)
        try await eventually { wantsB.grant != nil }
        #expect(wantsB.grant?.model == "B")
        #expect(h.backend.shutdowns == ["emulator-5554"])
    }

    @Test func rejectsUnknownModel() async throws {
        let h = Harness()
        let client = await h.claim(model: "Nope")
        try await eventually { client.failure != nil }
        #expect(await h.slots().isEmpty)
    }

    @Test func disconnectWhileQueuedLeavesTheQueue() async throws {
        let h = Harness(maxRunning: 1)
        let first = await h.claim(pid: 1)
        try await eventually { first.grant != nil }
        let waiting = await h.claim(pid: 2)
        #expect(await h.queue().count == 1)

        await h.broker.connectionClosed(waiting.conn)
        #expect(await h.queue().isEmpty)
    }

    @Test func unacknowledgedGrantReturnsToPoolWhenClientLeaves() async throws {
        let h = Harness()
        let client = await h.claim(acknowledge: false)
        try await eventually { client.grant != nil }

        await h.broker.connectionClosed(client.conn)
        try await eventually { await h.slots().first?.state == .free }
        #expect(h.backend.resets == ["emulator-5554"])
    }

    @Test func acknowledgedLeaseSurvivesDisconnect() async throws {
        let h = Harness()
        let client = await h.claim()
        try await eventually { await h.slots().first?.lease?.acknowledged == true }

        await h.broker.connectionClosed(client.conn)
        #expect(await h.slots().first?.state == .leased)
    }

    @Test func expiredLeaseIsReclaimed() async throws {
        let h = Harness()
        let client = await h.claim(ttl: 60)
        try await eventually { client.grant != nil }

        h.clock.advance(61)
        await h.broker.reap()
        try await eventually { await h.slots().first?.state == .free }
    }

    @Test func renewExtendsLease() async throws {
        let h = Harness()
        let client = await h.claim(ttl: 60)
        try await eventually { client.grant != nil }

        h.clock.advance(50)
        _ = await h.broker.renew("emulator-5554", ttl: 60)
        h.clock.advance(50)
        await h.broker.reap()
        #expect(await h.slots().first?.state == .leased)
    }

    @Test func deadOwnerLosesLease() async throws {
        let h = Harness()
        let client = await h.claim(pid: 42)
        try await eventually { client.grant != nil }

        h.owners.kill(42)
        await h.broker.reap()
        try await eventually { await h.slots().first?.state == .free }
    }

    @Test func idleEmulatorIsShutDown() async throws {
        let h = Harness(idle: 300)
        let client = await h.claim()
        try await eventually { client.grant != nil }
        _ = await h.broker.release("emulator-5554")
        try await eventually { await h.slots().first?.state == .free }

        h.clock.advance(301)
        await h.broker.reap()
        try await eventually { await h.slots().isEmpty }
    }

    @Test func failedResetRebootsFresh() async throws {
        let h = Harness(maxRunning: 1)
        h.backend.failResets()
        let first = await h.claim(pid: 1)
        try await eventually { first.grant != nil }
        let second = await h.claim(pid: 2)

        _ = await h.broker.release("emulator-5554")
        try await eventually { second.grant != nil }
        #expect(h.backend.shutdowns == ["emulator-5554"])
    }

    @Test func vanishedEmulatorIsDropped() async throws {
        let h = Harness()
        let client = await h.claim()
        try await eventually { client.grant != nil }

        h.backend.vanish("emulator-5554")
        for _ in 0..<Broker.missedTicksBeforeVanished { await h.broker.reap() }
        try await eventually { await h.slots().isEmpty }
    }

    @Test func repeatedBootFailuresFailTheWaiter() async throws {
        let h = Harness()
        h.backend.failBoot("Pixel")
        let client = await h.claim(model: "Pixel")
        try await eventually { client.failure != nil }
        #expect(client.failure?.contains("failed to boot") == true)
        try await eventually { await h.slots().isEmpty }
    }

    @Test func respectsGlobalCapacity() async throws {
        let h = Harness(maxRunning: 2, pool: [PoolEntry(name: "Pixel", maxInstances: 5)])
        let clients = await [h.claim(pid: 1), h.claim(pid: 2), h.claim(pid: 3)]
        try await eventually { clients.filter { $0.grant != nil }.count == 2 }
        #expect(await h.slots().count == 2)
        #expect(await h.queue().count == 1)
    }
}
