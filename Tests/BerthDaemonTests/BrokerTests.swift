@testable import BerthCore
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

    @Test
    func `physical devices are published but never become slots or grants`() async throws {
        let harness: Harness = .init(maxRunning: 1)
        let phone: PhysicalDevice = .mock()
        harness.backend.attach([phone])

        await harness.broker.reap()
        let client: Client = await harness.claim()
        try await eventually { client.grant != nil }

        let snapshot: StateSnapshot = await harness.broker.snapshot()
        #expect(snapshot.devices == [phone])
        #expect(snapshot.slots.map(\.serial) == ["emulator-5554"])
        #expect(client.grant?.serial == "emulator-5554")
    }

    @Test
    func `an unplugged device leaves the snapshot on the next reap`() async {
        let harness: Harness = .init()
        harness.backend.attach([.mock(serial: "A", model: nil, state: .unauthorized)])
        await harness.broker.reap()

        harness.backend.attach([])
        await harness.broker.reap()

        #expect(await harness.broker.snapshot().devices.isEmpty)
    }

    @Test
    func `an unmanaged emulator is published after phones under its avd name`() async {
        let harness: Harness = .init()
        let phone: PhysicalDevice = .mock()
        harness.backend.attach([phone])
        harness.backend.attachEmulators(
            [.mock(serial: "emulator-5556", model: "sdk_gphone64_arm64"), .mock(serial: "emulator-5554", model: "sdk_gphone64_arm64")],
            avdNames: ["emulator-5554": "Pixel_9"]
        )

        await harness.broker.reap()

        let devices: [PhysicalDevice] = await harness.broker.snapshot().devices
        #expect(devices.map(\.serial) == [phone.serial, "emulator-5554", "emulator-5556"])
        #expect(devices.map(\.model) == [phone.model, "Pixel_9", "sdk_gphone64_arm64"])
    }

    @Test
    func `an emulator without a model or avd name is published nameless`() async {
        let harness: Harness = .init()
        harness.backend.attachEmulators([.mock(serial: "emulator-5554", model: nil)])

        await harness.broker.reap()

        #expect(await harness.broker.snapshot().devices.map(\.model) == [nil])
    }

    @Test
    func `an unmanaged emulator never becomes a slot a grant or a running count`() async throws {
        let harness: Harness = .init(maxRunning: 1)
        harness.backend.attachEmulators([.mock(serial: "emulator-5554", model: "sdk")])
        harness.backend.setLive(["emulator-5554"])
        await harness.broker.reap()

        let client: Client = await harness.claim()
        try await eventually { client.grant != nil }

        let snapshot: StateSnapshot = await harness.broker.snapshot()
        #expect(client.grant?.serial == "emulator-5556")
        #expect(snapshot.slots.map(\.serial) == ["emulator-5556"])
        #expect(snapshot.devices.map(\.serial) == ["emulator-5554"])
        #expect(!harness.backend.shutdowns.contains("emulator-5554"))
    }

    @Test
    func `a managed emulator is never published whatever its slot state`() async throws {
        let harness: Harness = .init(maxRunning: 2)
        harness.backend.holdLaunches(true)
        let booting: Client = await harness.claim(pid: 1)
        try await eventually { await harness.slots().first?.state == .booting }
        harness.backend.attachEmulators([.mock(serial: "emulator-5554", model: "sdk", state: .offline)])
        await harness.broker.reap()
        #expect(await harness.broker.snapshot().devices.isEmpty)

        harness.backend.holdLaunches(false)
        try await eventually { booting.grant != nil }
        await harness.broker.reap()
        #expect(await harness.broker.snapshot().devices.isEmpty)

        harness.backend.holdShutdowns(true)
        _ = await harness.broker.stop("emulator-5554")
        await harness.broker.reap()
        #expect(await harness.slots().first?.state == .stopping)
        #expect(await harness.broker.snapshot().devices.isEmpty)
        harness.backend.holdShutdowns(false)
    }

    @Test
    func `an unmanaged emulator leaves the snapshot when it stops`() async {
        let harness: Harness = .init()
        harness.backend.attachEmulators([.mock(serial: "emulator-5554", model: "sdk")])
        await harness.broker.reap()

        harness.backend.attachEmulators([])
        await harness.broker.reap()

        #expect(await harness.broker.snapshot().devices.isEmpty)
    }

    @Test
    func `the avd name is asked once per serial while it stays listed`() async {
        let harness: Harness = .init()
        harness.backend.attachEmulators([.mock(serial: "emulator-5554", model: "sdk")], avdNames: ["emulator-5554": "Pixel_9"])

        await harness.broker.reap()
        await harness.broker.reap()
        await harness.broker.reap()
        #expect(harness.backend.avdNameCalls == ["emulator-5554"])

        harness.backend.attachEmulators([])
        await harness.broker.reap()
        harness.backend.attachEmulators([.mock(serial: "emulator-5554", model: "sdk")], avdNames: ["emulator-5554": "Pixel_9"])
        await harness.broker.reap()
        #expect(harness.backend.avdNameCalls == ["emulator-5554", "emulator-5554"])
    }
}
