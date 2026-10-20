import BerthCore
import Testing

@testable import BerthDaemon

@Suite
struct BrokerWindowedTests {
    private static let mixedPool: [PoolEntry] = [
        PoolEntry(name: "Pixel", maxInstances: 2),
        PoolEntry(name: "iPhone 17", platform: .ios, maxInstances: 1)
    ]

    @Test
    func `windowed claim boots a windowed slot even when a free headless one exists`() async throws {
        let h: Harness = .init(maxRunning: 3)
        let headless: Client = await h.claim(pid: 1)
        try await eventually { headless.grant != nil }
        _ = await h.broker.release("emulator-5554")
        try await eventually { await h.slots().first?.state == .free }

        let windowed: Client = await h.claim(model: "Pixel", pid: 2, windowed: true)
        try await eventually { windowed.grant != nil }

        #expect(windowed.grant?.serial == "emulator-5556")
        #expect(h.backend.launches.last == .init(serial: "emulator-5556", model: "Pixel", windowed: true))
        let slots: [Slot] = await h.slots()
        #expect(slots.first { $0.serial == "emulator-5556" }?.windowed == true)
        #expect(slots.first { $0.serial == "emulator-5554" }?.windowed == false)
    }

    @Test
    func `headless claim never gets a manually leased slot`() async throws {
        let h: Harness = .init(maxRunning: 1)
        let windowed: Client = await h.claim(model: "Pixel", pid: 1, windowed: true)
        try await eventually { windowed.grant != nil }

        let headless: Client = await h.claim(pid: 2)
        try await eventually { headless.lastPosition == 1 }
        await h.broker.reap()

        #expect(headless.grant == nil)
        #expect(h.backend.launches.map(\.windowed) == [true])
    }

    @Test
    func `dead owner and past expiry do not reclaim a manual lease`() async throws {
        let h: Harness = .init()
        let windowed: Client = await h.claim(model: "Pixel", pid: 42, windowed: true)
        try await eventually { windowed.grant != nil }
        #expect(windowed.grant?.expiresAt == .distantFuture)

        h.owners.kill(42)
        h.clock.advance(100_000)
        await h.broker.reap()

        let slot: Slot? = await h.slots().first
        #expect(slot?.state == .leased)
        #expect(h.backend.resets.isEmpty)
        #expect(h.backend.shutdowns.isEmpty)
    }

    @Test
    func `release of a manual lease turns the slot free without reset or shutdown`() async throws {
        let h: Harness = .init()
        let windowed: Client = await h.claim(model: "Pixel", windowed: true)
        try await eventually { windowed.grant != nil }

        let event: Event = await h.broker.release("emulator-5554")

        guard case let .ok(message) = event else {
            Issue.record("expected ok, got \(event)")
            return
        }
        #expect(message == "released emulator-5554; it stays running, free for the next claim")
        let slot: Slot? = await h.slots().first
        #expect(slot?.state == .free)
        #expect(slot?.lease == nil)
        #expect(slot?.windowed == true)
        #expect(h.backend.resets.isEmpty)
        #expect(h.backend.shutdowns.isEmpty)
        #expect(h.backend.isLive("emulator-5554"))
    }

    @Test
    func `the next headless claim takes a released windowed slot as is`() async throws {
        let h: Harness = .init()
        let windowed: Client = await h.claim(model: "Pixel", windowed: true)
        try await eventually { windowed.grant != nil }
        _ = await h.broker.release("emulator-5554")

        let agent: Client = await h.claim(pid: 2)
        try await eventually { agent.grant != nil }

        #expect(agent.grant?.serial == "emulator-5554")
        #expect(h.backend.launches.count == 1)
        #expect(h.backend.resets.isEmpty)
        #expect(await h.slots().first?.lease?.manual == false)
    }

    @Test
    func `agent release of a windowed slot resets it with a window`() async throws {
        let h: Harness = .init()
        let windowed: Client = await h.claim(model: "Pixel", windowed: true)
        try await eventually { windowed.grant != nil }
        _ = await h.broker.release("emulator-5554")
        let agent: Client = await h.claim(pid: 2)
        try await eventually { agent.grant != nil }

        _ = await h.broker.release("emulator-5554")

        try await eventually { await h.slots().first?.state == .free }
        #expect(h.backend.resets == ["emulator-5554"])
        #expect(h.backend.resetWindowed == [true])
        #expect(await h.slots().first?.windowed == true)
    }

    @Test
    func `agent lease on a windowed slot is reclaimed when its owner dies`() async throws {
        let h: Harness = .init()
        let windowed: Client = await h.claim(model: "Pixel", windowed: true)
        try await eventually { windowed.grant != nil }
        _ = await h.broker.release("emulator-5554")
        let agent: Client = await h.claim(pid: 42)
        try await eventually { agent.grant != nil }

        h.owners.kill(42)
        await h.broker.reap()

        try await eventually { h.backend.resetWindowed == [true] }
    }

    @Test
    func `agent lease on a windowed slot is reclaimed when its ttl expires`() async throws {
        let h: Harness = .init()
        let windowed: Client = await h.claim(model: "Pixel", windowed: true)
        try await eventually { windowed.grant != nil }
        _ = await h.broker.release("emulator-5554")
        let agent: Client = await h.claim(pid: 2, ttl: 60)
        try await eventually { agent.grant != nil }

        h.clock.advance(61)
        await h.broker.reap()

        try await eventually { h.backend.resetWindowed == [true] }
    }

    @Test
    func `windowed claim reuses a free windowed slot of its model`() async throws {
        let h: Harness = .init()
        let first: Client = await h.claim(model: "Pixel", pid: 1, windowed: true)
        try await eventually { first.grant != nil }
        _ = await h.broker.release("emulator-5554")

        let second: Client = await h.claim(model: "Pixel", pid: 2, windowed: true)
        try await eventually { second.grant != nil }

        #expect(second.grant?.serial == "emulator-5554")
        #expect(h.backend.launches.count == 1)
        #expect(await h.slots().first?.lease?.manual == true)
    }

    @Test
    func `a windowed waiter has priority over an earlier headless waiter on a free windowed slot`() async throws {
        let h: Harness = .init(maxRunning: 1, pool: [PoolEntry(name: "Pixel", maxInstances: 1)])
        let first: Client = await h.claim(model: "Pixel", pid: 1, windowed: true)
        try await eventually { first.grant != nil }
        let headless: Client = await h.claim(model: "Pixel", pid: 2)
        let windowed: Client = await h.claim(model: "Pixel", pid: 3, windowed: true)
        try await eventually { headless.lastPosition == 1 && windowed.lastPosition == 2 }

        _ = await h.broker.release("emulator-5554")

        try await eventually { windowed.grant != nil }
        #expect(headless.grant == nil)
    }

    @Test
    func `headless claim never takes a booting windowed slot`() async throws {
        let h: Harness = .init()
        h.backend.holdLaunches(true)
        let windowed: Client = await h.claim(model: "Pixel", pid: 1, windowed: true)
        try await eventually { await h.slots().first?.state == .booting }

        let headless: Client = await h.claim(pid: 2)
        try await eventually { h.backend.launches.count == 2 }
        h.backend.holdLaunches(false)
        try await eventually { windowed.grant != nil && headless.grant != nil }

        #expect(h.backend.launches.map(\.windowed) == [true, false])
        #expect(headless.grant?.serial == "emulator-5556")
    }

    @Test
    func `idle shutdown stops a free windowed slot`() async throws {
        let h: Harness = .init()
        let windowed: Client = await h.claim(model: "Pixel", windowed: true)
        try await eventually { windowed.grant != nil }
        _ = await h.broker.release("emulator-5554")

        h.clock.advance(901)
        await h.broker.reap()

        try await eventually { await h.slots().isEmpty }
        #expect(h.backend.shutdowns == ["emulator-5554"])
    }

    @Test
    func `stop-all stops a free windowed slot and keeps a manual lease`() async throws {
        let h: Harness = .init()
        let kept: Client = await h.claim(model: "Pixel", pid: 1, windowed: true)
        let freed: Client = await h.claim(model: "Pixel", pid: 2, windowed: true)
        try await eventually { kept.grant != nil && freed.grant != nil }
        _ = await h.broker.release("emulator-5556")

        _ = await h.broker.stopAll()

        try await eventually { await h.slots().map(\.serial) == ["emulator-5554"] }
        #expect(h.backend.shutdowns == ["emulator-5556"])
    }

    @Test
    func `stop-all skips manual leases and explicit stop stops them`() async throws {
        let h: Harness = .init()
        let windowed: Client = await h.claim(model: "Pixel", pid: 1, windowed: true)
        let headless: Client = await h.claim(pid: 2)
        try await eventually { windowed.grant != nil && headless.grant != nil }

        _ = await h.broker.stopAll()
        try await eventually { await h.slots().map(\.serial) == ["emulator-5554"] }
        #expect(await h.slots().first?.state == .leased)
        #expect(h.backend.shutdowns == ["emulator-5556"])

        _ = await h.broker.stop("emulator-5554")
        try await eventually { await h.slots().isEmpty }
        #expect(h.backend.shutdowns.contains("emulator-5554"))
    }

    @Test
    func `stop-all stops a windowed slot that is still booting and fails its waiter`() async throws {
        let h: Harness = .init()
        h.backend.holdLaunches(true)
        let windowed: Client = await h.claim(model: "Pixel", windowed: true)
        try await eventually { await h.slots().first?.state == .booting }

        _ = await h.broker.stopAll()
        h.backend.holdLaunches(false)

        try await eventually { await h.slots().isEmpty }
        #expect(windowed.failure != nil)
        #expect(windowed.grant == nil)
    }

    @Test
    func `windowed claim stops the free headless slot that fills its model and boots windowed`() async throws {
        let h: Harness = .init(maxRunning: 3, pool: [PoolEntry(name: "Pixel", maxInstances: 1)])
        let headless: Client = await h.claim(pid: 1)
        try await eventually { headless.grant != nil }
        _ = await h.broker.release("emulator-5554")
        try await eventually { await h.slots().first?.state == .free }

        let windowed: Client = await h.claim(model: "Pixel", pid: 2, windowed: true)
        try await eventually { windowed.grant != nil }

        #expect(h.backend.shutdowns == ["emulator-5554"])
        #expect(h.backend.launches.last?.windowed == true)
    }

    @Test
    func `a windowed waiter without room does not hide another model's stop from the next waiter`() async throws {
        let pool: [PoolEntry] = ["A", "B", "C", "D"].map { PoolEntry(name: $0, maxInstances: 1) }
        let h: Harness = .init(maxRunning: 3, pool: pool)
        let a: Client = await h.claim(model: "A", pid: 1)
        try await eventually { a.grant != nil }
        for model in ["B", "C"] {
            let client: Client = await h.claim(model: model, pid: 2)
            try await eventually { client.grant != nil }
            let serial: String = try #require(client.grant?.serial)
            _ = await h.broker.release(serial)
        }
        try await eventually { await h.slots().filter { $0.state == .free }.count == 2 }
        let stoppedB: String = try #require(await h.slots().first { $0.model == "B" }?.serial)
        let freeC: String = try #require(await h.slots().first { $0.model == "C" }?.serial)

        h.backend.holdShutdowns(true)
        _ = await h.broker.stop(stoppedB)
        _ = await h.claim(model: "A", pid: 3, windowed: true)
        _ = await h.claim(model: "D", pid: 4)
        await h.broker.reap()

        #expect(await h.slots().first { $0.serial == freeC }?.state == .free)
        h.backend.holdShutdowns(false)
    }

    @Test
    func `renew refuses a manual lease`() async throws {
        let h: Harness = .init()
        let windowed: Client = await h.claim(model: "Pixel", windowed: true)
        try await eventually { windowed.grant != nil }

        let event: Event = await h.broker.renew("emulator-5554", ttl: 60)

        guard case let .failure(message) = event else {
            Issue.record("expected failure, got \(event)")
            return
        }
        #expect(message.contains("never expires"))
        #expect(await h.slots().first?.lease?.expiresAt == .distantFuture)
    }

    @Test
    func `eviction never stops a manually leased slot`() async throws {
        let h: Harness = .init(maxRunning: 1, pool: [PoolEntry(name: "A", maxInstances: 1), PoolEntry(name: "B", maxInstances: 1)])
        let windowed: Client = await h.claim(model: "A", pid: 1, windowed: true)
        try await eventually { windowed.grant != nil }

        let other: Client = await h.claim(model: "B", pid: 2)
        try await eventually { other.lastPosition == 1 }
        await h.broker.reap()

        #expect(other.grant == nil)
        #expect(h.backend.shutdowns.isEmpty)
    }

    @Test
    func `eviction stops a free windowed slot`() async throws {
        let h: Harness = .init(maxRunning: 1, pool: [PoolEntry(name: "A", maxInstances: 1), PoolEntry(name: "B", maxInstances: 1)])
        let windowed: Client = await h.claim(model: "A", pid: 1, windowed: true)
        try await eventually { windowed.grant != nil }
        _ = await h.broker.release("emulator-5554")

        let other: Client = await h.claim(model: "B", pid: 2)
        try await eventually { other.grant != nil }

        #expect(h.backend.shutdowns == ["emulator-5554"])
    }

    @Test
    func `windowed claim may evict an idle headless slot`() async throws {
        let h: Harness = .init(maxRunning: 1, pool: [PoolEntry(name: "A", maxInstances: 1), PoolEntry(name: "B", maxInstances: 1)])
        let first: Client = await h.claim(model: "B", pid: 1)
        try await eventually { first.grant != nil }
        _ = await h.broker.release("emulator-5554")
        try await eventually { await h.slots().first?.state == .free }

        let windowed: Client = await h.claim(model: "A", pid: 2, windowed: true)
        try await eventually { windowed.grant != nil }

        #expect(h.backend.shutdowns == ["emulator-5554"])
    }

    @Test
    func `idle check ignores a manual lease`() async throws {
        let h: Harness = .init()
        let windowed: Client = await h.claim(model: "Pixel", windowed: true)
        try await eventually { windowed.grant != nil }

        #expect(await h.broker.performIfIdle {})
    }

    @Test
    func `windowed claim for an ios model or without a model fails`() async throws {
        let h: Harness = .init(pool: Self.mixedPool)
        let ios: Client = await h.claim(model: "iPhone 17", platform: .ios, windowed: true)
        let noModel: Client = await h.claim(windowed: true)
        let unknown: Client = await h.claim(model: "Nope", windowed: true)
        try await eventually { ios.failure != nil && noModel.failure != nil && unknown.failure != nil }

        let message: String = "windowed launch needs an Android pool AVD"
        #expect(ios.failure == message)
        #expect(noModel.failure == message)
        #expect(unknown.failure == message)
        #expect(h.backend.launches.isEmpty)
    }

    @Test
    func `windowed slot that vanishes is stopped and removed`() async throws {
        let h: Harness = .init()
        let windowed: Client = await h.claim(model: "Pixel", windowed: true)
        try await eventually { windowed.grant != nil }

        h.backend.vanish("emulator-5554")
        for _ in 0..<Broker.missedTicksBeforeVanished { await h.broker.reap() }

        try await eventually { await h.slots().isEmpty }
    }
}
