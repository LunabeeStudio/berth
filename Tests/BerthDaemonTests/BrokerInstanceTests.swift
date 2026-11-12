import BerthCore
import Foundation
import Testing

@testable import BerthDaemon

@Suite
struct BrokerInstanceTests {
    private static let twoModels: [PoolEntry] = [
        PoolEntry(name: "Pixel_9", maxInstances: 2),
        PoolEntry(name: "Pixel_10", maxInstances: 2)
    ]

    @Test
    func `two boots of the same model get 1 and 2`() async throws {
        let h: Harness = .init()
        let first: Client = await h.claim(pid: 1)
        let second: Client = await h.claim(pid: 2)
        try await eventually { first.grant != nil && second.grant != nil }

        #expect(await instances(h) == ["emulator-5554": 1, "emulator-5556": 2])
        #expect(await h.slots().first?.displayName == "Pixel - 1")
    }

    @Test
    func `numbers count per model`() async throws {
        let h: Harness = .init(maxRunning: 2, pool: Self.twoModels)
        let nine: Client = await h.claim(model: "Pixel_9", pid: 1)
        let ten: Client = await h.claim(model: "Pixel_10", pid: 2)
        try await eventually { nine.grant != nil && ten.grant != nil }

        #expect(await h.slots().compactMap(\.instance) == [1, 1])
    }

    @Test
    func `a slot keeps its number across release and reset`() async throws {
        let h: Harness = .init()
        let first: Client = await h.claim(pid: 1)
        let second: Client = await h.claim(pid: 2)
        try await eventually { first.grant != nil && second.grant != nil }

        _ = await h.broker.release("emulator-5556")
        try await eventually { await h.slots().first { $0.serial == "emulator-5556" }?.state == .free }

        #expect(await instances(h) == ["emulator-5554": 1, "emulator-5556": 2])
    }

    @Test
    func `the number of a stopped slot is reused by the next boot`() async throws {
        let h: Harness = .init()
        let first: Client = await h.claim(pid: 1)
        let second: Client = await h.claim(pid: 2)
        try await eventually { first.grant != nil && second.grant != nil }

        _ = await h.broker.stop("emulator-5554")
        try await eventually { await h.slots().map(\.serial) == ["emulator-5556"] }
        let third: Client = await h.claim(pid: 3)
        try await eventually { third.grant != nil }

        #expect(await instances(h)[third.grant?.serial ?? ""] == 1)
        #expect(await instances(h)["emulator-5556"] == 2)
    }

    @Test
    func `restore keeps saved numbers and numbers the slots that lack one`() async throws {
        let url: URL = FileManager.default.temporaryDirectory.appendingPathComponent("berth-state-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let entries: [String] = [("emulator-5556", ""), ("emulator-5554", ""), ("emulator-5558", #","instance":1"#)].map {
            #"{"serial":"\#($0.0)","model":"Pixel","state":"free","stateSince":0,"generation":1\#($0.1)}"#
        }
        try Data("[\(entries.joined(separator: ","))]".utf8).write(to: url)
        let store: StateStore = .init(url: url)
        let h: Harness = .init(maxRunning: 3, pool: [PoolEntry(name: "Pixel", maxInstances: 3)], store: store)
        h.backend.setLive(["emulator-5554", "emulator-5556", "emulator-5558"])

        await h.broker.restore()

        #expect(await instances(h) == ["emulator-5554": 2, "emulator-5556": 3, "emulator-5558": 1])
    }

    private func instances(_ h: Harness) async -> [String: Int] {
        Dictionary(uniqueKeysWithValues: await h.slots().compactMap { slot in slot.instance.map { (slot.serial, $0) } })
    }
}
