import BerthCore
@testable import BerthDaemon
import Foundation
import Synchronization
import Testing

final class FakeBackend: DeviceBackend {
    private let state = Mutex(State())

    struct State {
        var live: Set<String> = []
        var failingModels: Set<String> = []
        var failReset = false
        var resets: [String] = []
        var shutdowns: [String] = []
    }

    func failBoot(_ model: String) { state.withLock { _ = $0.failingModels.insert(model) } }
    func failResets() { state.withLock { $0.failReset = true } }
    func vanish(_ serial: String) { state.withLock { _ = $0.live.remove(serial) } }
    var resets: [String] { state.withLock { $0.resets } }
    var shutdowns: [String] { state.withLock { $0.shutdowns } }

    func nextSerial(model: String, taken: Set<String>) -> String? {
        stride(from: 5554, through: 5600, by: 2).map { "emulator-\($0)" }.first { !taken.contains($0) }
    }

    func launch(serial: String, model: String) async throws -> Int32? {
        if state.withLock({ $0.failingModels.contains(model) }) { throw BackendError.exited(serial) }
        state.withLock { _ = $0.live.insert(serial) }
        return nil
    }

    func waitReady(serial: String, pid: Int32?) async throws {}

    func reset(serial: String, model: String, pid: Int32?) async throws -> Int32? {
        try state.withLock {
            $0.resets.append(serial)
            if $0.failReset { throw BackendError.exited(serial) }
        }
        return pid
    }

    func shutdown(serial: String, pid: Int32?) async {
        state.withLock {
            $0.shutdowns.append(serial)
            $0.live.remove(serial)
        }
    }

    func liveSerials() async -> Set<String>? { state.withLock { $0.live } }
    func isProcessAlive(_ pid: Int32) -> Bool { true }
}

final class TestClock: Sendable {
    private let current = Mutex(Date(timeIntervalSince1970: 1_000_000))
    var now: Date { current.withLock { $0 } }
    func advance(_ seconds: TimeInterval) { current.withLock { $0 = $0.addingTimeInterval(seconds) } }
}

final class OwnerRegistry: Sendable {
    private let dead = Mutex<Set<Int32>>([])
    func kill(_ pid: Int32) { dead.withLock { _ = $0.insert(pid) } }
    func isAlive(_ owner: Owner) -> Bool { !dead.withLock { $0.contains(owner.pid) } }
}

final class EventLog: Sendable {
    let events = Mutex<[Event]>([])
}

final class Client: Sendable {
    let conn = UUID()
    let sink: AsyncStream<Event>.Continuation
    private let log = EventLog()

    init() {
        let (stream, sink) = AsyncStream.makeStream(of: Event.self)
        self.sink = sink
        let log = log
        Task { for await event in stream { log.events.withLock { $0.append(event) } } }
    }

    var grant: Grant? {
        log.events.withLock { $0.compactMap { if case let .granted(grant) = $0 { grant } else { nil } }.first }
    }

    var failure: String? {
        log.events.withLock { $0.compactMap { if case let .failure(message) = $0 { message } else { nil } }.first }
    }

    var lastPosition: Int? {
        log.events.withLock { $0.compactMap { if case let .queued(position) = $0 { position } else { nil } }.last }
    }
}

struct Harness {
    let backend = FakeBackend()
    let clock = TestClock()
    let owners = OwnerRegistry()
    let broker: Broker

    init(maxRunning: Int = 2, pool: [PoolEntry] = [PoolEntry(avd: "Pixel", maxInstances: 2)], idle: Int = 900) {
        let clock = clock
        let owners = owners
        broker = Broker(
            config: Config(maxRunning: maxRunning, idleShutdownSeconds: idle, defaultTTLSeconds: 3600, pool: pool),
            backend: backend,
            now: { clock.now },
            ownerAlive: { owners.isAlive($0) }
        )
    }

    @discardableResult
    func claim(model: String? = nil, pid: Int32 = 100, ttl: Int? = nil, acknowledge: Bool = true) async -> Client {
        let client = Client()
        let request = ClaimRequest(model: model, ttl: ttl, label: nil, owner: Owner(pid: pid, startTime: nil, name: "agent"))
        await broker.claim(request, conn: client.conn, sink: client.sink)
        if acknowledge {
            Task {
                guard (try? await eventually { client.grant != nil }) != nil, let grant = client.grant else { return }
                await broker.acknowledge(lease: grant.leaseID, conn: client.conn)
            }
        }
        return client
    }

    func slots() async -> [Slot] { await broker.snapshot().slots }
    func queue() async -> [WaiterInfo] { await broker.snapshot().queue }
}

struct Timeout: Error {}

func eventually(_ condition: @Sendable () async -> Bool) async throws {
    for _ in 0..<200 {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw Timeout()
}

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
        let h = Harness(maxRunning: 1, pool: [PoolEntry(avd: "A", maxInstances: 1), PoolEntry(avd: "B", maxInstances: 1)])
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
        let h = Harness(maxRunning: 1, pool: [PoolEntry(avd: "A", maxInstances: 1), PoolEntry(avd: "B", maxInstances: 1)])
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
        let h = Harness(maxRunning: 2, pool: [PoolEntry(avd: "Pixel", maxInstances: 5)])
        let clients = await [h.claim(pid: 1), h.claim(pid: 2), h.claim(pid: 3)]
        try await eventually { clients.filter { $0.grant != nil }.count == 2 }
        #expect(await h.slots().count == 2)
        #expect(await h.queue().count == 1)
    }
}
