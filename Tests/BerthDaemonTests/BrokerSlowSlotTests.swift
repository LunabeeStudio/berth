import BerthCore
@testable import BerthDaemon
import Foundation
import Testing

@Suite
struct BrokerSlowSlotTests {
    @Test
    func `waiter keeps waiting on a reset under 60 s`() async throws {
        let h: Harness = .init()
        try await startSlowReset(h)

        let waiter: Client = await h.claim(pid: 2)
        h.clock.advance(59)
        await h.broker.reap()

        try await eventually { waiter.lastPosition == 1 }
        #expect(await h.slots().count == 1)
        #expect(waiter.grant == nil)
    }

    @Test
    func `waiter gets a new boot once the reset passes 60 s`() async throws {
        let h: Harness = .init()
        try await startSlowReset(h)

        let waiter: Client = await h.claim(pid: 2)
        h.clock.advance(60)
        await h.broker.reap()

        try await eventually { waiter.grant != nil }
        #expect(waiter.grant?.serial == "emulator-5556")
        #expect(h.backend.launches.count == 2)
    }

    @Test
    func `slow reset is not stopped and serves the waiter when it ends`() async throws {
        let h: Harness = .init(maxRunning: 1)
        try await startSlowReset(h)

        let waiter: Client = await h.claim(pid: 2)
        h.clock.advance(120)
        await h.broker.reap()

        #expect(await h.slots().map(\.state) == [.resetting])
        #expect(waiter.grant == nil)

        h.backend.holdResets(false)
        try await eventually { waiter.grant != nil }
        #expect(waiter.grant?.serial == "emulator-5554")
        #expect(await h.slots().count == 1)
    }

    @Test
    func `slow reset does not evict a free slot of another model`() async throws {
        let h: Harness = .init(pool: [PoolEntry(name: "A", maxInstances: 2), PoolEntry(name: "B", maxInstances: 1)])
        let holderA: Client = await h.claim(model: "A", pid: 1)
        let holderB: Client = await h.claim(model: "B", pid: 2)
        try await eventually { holderA.grant != nil && holderB.grant != nil }
        _ = await h.broker.release(try #require(holderB.grant).serial)
        try await eventually { await h.slots().first { $0.model == "B" }?.state == .free }
        h.backend.holdResets(true)
        _ = await h.broker.release(try #require(holderA.grant).serial)
        try await eventually { await h.slots().first { $0.model == "A" }?.state == .resetting }

        let waiter: Client = await h.claim(model: "A", pid: 3)
        h.clock.advance(120)
        await h.broker.reap()

        try await eventually { waiter.lastPosition == 1 }
        let slots: [Slot] = await h.slots()
        #expect(slots.count == 2)
        #expect(slots.first { $0.model == "A" }?.state == .resetting)
        #expect(slots.first { $0.model == "B" }?.state == .free)
    }

    @Test
    func `a waiter boots only once past a slow slot`() async throws {
        let h: Harness = .init(maxRunning: 5, pool: [PoolEntry(name: "Pixel", maxInstances: 5)])
        try await startSlowReset(h)
        h.backend.holdLaunches(true)

        _ = await h.claim(pid: 2)
        h.clock.advance(60)
        await h.broker.reap()
        #expect(await h.slots().count == 2)

        for _ in 0..<3 {
            h.clock.advance(120)
            await h.broker.reap()
        }
        #expect(await h.slots().count == 2)
        h.backend.holdLaunches(false)
    }

    @Test
    func `a boot granted to another waiter does not stop the slow slot being replaced`() async throws {
        let h: Harness = .init(maxRunning: 5, pool: [PoolEntry(name: "Pixel", maxInstances: 5)])
        try await startSlowReset(h)

        let first: Client = await h.claim(pid: 2)
        let second: Client = await h.claim(pid: 3)
        try await eventually { first.grant != nil }
        #expect(first.grant?.serial == "emulator-5556")

        h.clock.advance(60)
        await h.broker.reap()

        try await eventually { second.grant != nil }
        let slotCount: Int = await h.slots().count
        #expect(slotCount == 3)
    }

    @Test
    func `each of two slow slots gets one replacement`() async throws {
        let h: Harness = .init(maxRunning: 5, pool: [PoolEntry(name: "Pixel", maxInstances: 5)])
        let holders: [Client] = [await h.claim(pid: 1), await h.claim(pid: 2)]
        try await eventually { holders.allSatisfy { $0.grant != nil } }
        h.backend.holdResets(true)
        for holder in holders { _ = await h.broker.release(try #require(holder.grant).serial) }
        try await eventually { await h.slots().allSatisfy { $0.state == .resetting } }

        h.backend.holdLaunches(true)
        let first: Client = await h.claim(pid: 3)
        let second: Client = await h.claim(pid: 4)
        for _ in 0..<3 {
            h.clock.advance(60)
            await h.broker.reap()
        }
        let heldCount: Int = await h.slots().count
        #expect(heldCount == 4)

        h.backend.holdLaunches(false)
        try await eventually { first.grant != nil && second.grant != nil }
        let finalCount: Int = await h.slots().count
        #expect(finalCount == 4)
    }

    @Test
    func `a slow reset and a slow claim-time boot get one replacement each`() async throws {
        let h: Harness = .init(maxRunning: 5, pool: [PoolEntry(name: "Pixel", maxInstances: 5)])
        try await startSlowReset(h)
        h.backend.holdLaunches(true)

        _ = await h.claim(pid: 2)
        _ = await h.claim(pid: 3)
        h.clock.advance(60)
        await h.broker.reap()
        let firstCount: Int = await h.slots().count
        #expect(firstCount == 4)

        for _ in 0..<3 {
            h.clock.advance(120)
            await h.broker.reap()
        }
        let finalCount: Int = await h.slots().count
        #expect(finalCount == 4)
        h.backend.holdLaunches(false)
    }

    @Test
    func `a failed replacement boot lets the next pass boot another`() async throws {
        let h: Harness = .init(maxRunning: 5, pool: [PoolEntry(name: "Pixel", maxInstances: 5)])
        try await startSlowReset(h)
        h.backend.holdLaunches(true)

        _ = await h.claim(pid: 2)
        h.clock.advance(60)
        await h.broker.reap()
        try await eventually { h.backend.launches.count == 2 }

        h.backend.failBoot("Pixel")
        h.backend.holdLaunches(false)
        try await eventually {
            await h.broker.reap()
            return h.backend.launches.count >= 3
        }
    }

    @Test
    func `a new waiter gets a boot once the replacement went to another waiter`() async throws {
        let h: Harness = .init(maxRunning: 5, pool: [PoolEntry(name: "Pixel", maxInstances: 5)])
        try await startSlowReset(h)

        let first: Client = await h.claim(pid: 2)
        h.clock.advance(60)
        await h.broker.reap()
        try await eventually { first.grant != nil }

        _ = await h.claim(pid: 3)
        await h.broker.reap()
        try await eventually { h.backend.launches.count == 3 }
    }
}

private extension BrokerSlowSlotTests {
    func startSlowReset(_ h: Harness) async throws {
        let holder: Client = await h.claim(pid: 1)
        try await eventually { holder.grant != nil }
        h.backend.holdResets(true)
        _ = await h.broker.release(try #require(holder.grant).serial)
        try await eventually { await h.slots().first?.state == .resetting }
    }
}
