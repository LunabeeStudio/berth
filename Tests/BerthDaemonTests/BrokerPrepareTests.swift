import BerthCore
import Foundation
import Testing

@testable import BerthDaemon

@Suite
struct BrokerPrepareTests {
    private static let pool: [PoolEntry] = [
        PoolEntry(name: "Pixel", maxInstances: 2),
        PoolEntry(name: "iPhone 17", platform: .ios, maxInstances: 1)
    ]

    private struct Setup {
        let h: Harness
        let preparer: FakePreparer
        let configURL: URL
    }

    private static func setup(maxRunning: Int = 2) throws -> Setup {
        let preparer: FakePreparer = .init(avds: ["Pixel", "Fresh"])
        let configURL: URL = FileManager.default.temporaryDirectory.appending(path: "berth-prepare-\(UUID().uuidString).json")
        try Data(#"{"extra": "kept", "pool": [{"avd": "Pixel", "maxInstances": 2}]}"#.utf8).write(to: configURL)
        let h: Harness = .init(maxRunning: maxRunning, pool: pool, preparer: preparer, configURL: configURL)
        return Setup(h: h, preparer: preparer, configURL: configURL)
    }

    private static func prepare(_ h: Harness, avd: String) async -> Client {
        let client: Client = .init()
        await h.broker.prepare(.init(avd: avd, settle: 0), conn: client.conn, sink: client.sink)
        return client
    }

    @Test
    func `a successful prepare joins the pool and a later claim is granted`() async throws {
        let s: Setup = try Self.setup()

        let client: Client = await Self.prepare(s.h, avd: "Fresh")
        try await eventually { !client.notices.isEmpty }

        #expect(client.notices == ["saved snapshot 'berth-clean' for Fresh"])
        #expect(client.progress == ["cold booting Fresh as emulator-5554"])
        #expect(await s.h.slots().isEmpty)
        #expect(try Config.load(from: s.configURL)?.pool.map(\.name) == ["Pixel", "Fresh"])
        let claim: Client = await s.h.claim(model: "Fresh")
        try await eventually { claim.grant != nil }
        #expect(claim.grant?.model == "Fresh")
    }

    @Test
    func `a preparing slot shows in the snapshot`() async throws {
        let s: Setup = try Self.setup()
        s.preparer.holdPrepares(true)

        _ = await Self.prepare(s.h, avd: "Fresh")

        let slot: Slot? = await s.h.slots().first
        #expect(slot?.state == .preparing)
        #expect(slot?.model == "Fresh")
    }

    @Test
    func `a claim during the prepare queues and is granted after it`() async throws {
        let s: Setup = try Self.setup()
        s.preparer.holdPrepares(true)
        let prepare: Client = await Self.prepare(s.h, avd: "Pixel")
        try await eventually { await s.h.slots().first?.state == .preparing }

        let claim: Client = await s.h.claim(model: "Pixel")
        try await eventually { claim.lastPosition == 1 }
        await s.h.broker.reap()

        #expect(claim.grant == nil)
        #expect(s.h.backend.launches.isEmpty)
        s.preparer.holdPrepares(false)
        try await eventually { claim.grant != nil }
        #expect(!prepare.notices.isEmpty)
        #expect(s.h.backend.launches.count == 1)
    }

    @Test
    func `free instances are stopped before the prepare starts`() async throws {
        let s: Setup = try Self.setup()
        let first: Client = await s.h.claim(model: "Pixel")
        try await eventually { first.grant != nil }
        _ = await s.h.broker.release("emulator-5554")
        try await eventually { await s.h.slots().first?.state == .free }

        let client: Client = await Self.prepare(s.h, avd: "Pixel")
        try await eventually { !client.notices.isEmpty }

        #expect(s.h.backend.shutdowns == ["emulator-5554"])
        #expect(s.preparer.calls == ["emulator-5556"])
    }

    @Test
    func `a leased instance refuses the prepare and stays running`() async throws {
        let s: Setup = try Self.setup()
        let first: Client = await s.h.claim(model: "Pixel")
        try await eventually { first.grant != nil }

        let client: Client = await Self.prepare(s.h, avd: "Pixel")
        try await eventually { client.failure != nil }

        #expect(client.failure == "Pixel is in use: emulator-5554 leased by agent#100")
        #expect(s.preparer.calls.isEmpty)
        #expect(s.h.backend.shutdowns.isEmpty)
        #expect(await s.h.slots().first?.state == .leased)
    }

    @Test
    func `an emulator running outside berth refuses the prepare`() async throws {
        let s: Setup = try Self.setup()
        s.h.backend.setLive(["emulator-5554"])
        s.preparer.setName("Fresh", of: "emulator-5554")

        let client: Client = await Self.prepare(s.h, avd: "Fresh")
        try await eventually { client.failure != nil }

        #expect(client.failure == "Fresh is already running as emulator-5554; close it first")
        #expect(s.preparer.calls.isEmpty)
    }

    @Test
    func `an android emulator outside berth is seen when the pool has no android entry`() async throws {
        let preparer: FakePreparer = .init(avds: ["Fresh"])
        let configURL: URL = FileManager.default.temporaryDirectory.appending(path: "berth-prepare-\(UUID().uuidString).json")
        try Data(#"{"pool": [{"simulator": "iPhone 17", "maxInstances": 1}]}"#.utf8).write(to: configURL)
        let h: Harness = .init(pool: [PoolEntry(name: "iPhone 17", platform: .ios, maxInstances: 1)], preparer: preparer, configURL: configURL)
        preparer.setLive(["emulator-5554"])
        preparer.setName("Fresh", of: "emulator-5554")

        let client: Client = await Self.prepare(h, avd: "Fresh")
        try await eventually { client.failure != nil }

        #expect(client.failure == "Fresh is already running as emulator-5554; close it first")
        preparer.setName("Other", of: "emulator-5554")
        preparer.holdPrepares(true)
        _ = await Self.prepare(h, avd: "Fresh")
        try await eventually { await h.slots().first?.state == .preparing }
        #expect(await h.slots().first?.serial == "emulator-5556")
    }

    @Test
    func `a disconnect cancels the prepare and leaves the pool unchanged`() async throws {
        let s: Setup = try Self.setup()
        s.preparer.holdPrepares(true)
        let client: Client = await Self.prepare(s.h, avd: "Fresh")
        try await eventually { await s.h.slots().first?.state == .preparing }

        await s.h.broker.connectionClosed(client.conn)

        try await eventually { await s.h.slots().isEmpty }
        #expect(s.preparer.cancelled == ["emulator-5554"])
        #expect(try Config.load(from: s.configURL)?.pool.map(\.name) == ["Pixel"])
    }

    @Test
    func `stop-all during a prepare cancels it and tells the client`() async throws {
        let s: Setup = try Self.setup()
        s.preparer.holdPrepares(true)
        let client: Client = await Self.prepare(s.h, avd: "Fresh")
        try await eventually { await s.h.slots().first?.state == .preparing }

        _ = await s.h.broker.stopAll()

        try await eventually { client.failure != nil }
        #expect(client.failure == "prepare of Fresh cancelled")
        #expect(s.preparer.cancelled == ["emulator-5554"])
        #expect(await s.h.slots().isEmpty)
    }

    @Test
    func `a failed prepare reports it and leaves the pool unchanged`() async throws {
        let s: Setup = try Self.setup()
        s.preparer.failPrepares("snapshot save failed")

        let client: Client = await Self.prepare(s.h, avd: "Fresh")
        try await eventually { client.failure != nil }

        #expect(client.failure == "snapshot save failed")
        #expect(await s.h.slots().isEmpty)
        #expect(try Config.load(from: s.configURL)?.pool.map(\.name) == ["Pixel"])
    }

    @Test
    func `iOS entries and unknown AVDs are refused`() async throws {
        let s: Setup = try Self.setup()

        let ios: Client = await Self.prepare(s.h, avd: "iPhone 17")
        let unknown: Client = await Self.prepare(s.h, avd: "Nope")
        try await eventually { ios.failure != nil && unknown.failure != nil }

        #expect(ios.failure == "'iPhone 17' is an iOS simulator; berth erases simulators on release, so prepare is Android-only")
        #expect(unknown.failure == "unknown AVD 'Nope'")
        #expect(await s.h.slots().isEmpty)
    }

    @Test
    func `a prepare starts even at the running limit`() async throws {
        let s: Setup = try Self.setup(maxRunning: 1)
        let first: Client = await s.h.claim(model: "Pixel")
        try await eventually { first.grant != nil }
        s.preparer.holdPrepares(true)

        _ = await Self.prepare(s.h, avd: "Fresh")

        let states: [SlotState] = await s.h.slots().map(\.state)
        #expect(states.sorted { $0.rawValue < $1.rawValue } == [.leased, .preparing])
    }
}
