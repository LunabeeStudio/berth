import BerthCore
import Foundation
import Testing

@testable import BerthDaemon

@Suite
struct BrokerRestoreTests {
    private let url: URL = FileManager.default.temporaryDirectory.appendingPathComponent("berth-state-\(UUID().uuidString).json")

    private func harness(saving slots: [Slot]) -> Harness {
        let store: StateStore = .init(url: url)
        store.save(slots)
        return .init(maxRunning: 3, pool: [PoolEntry(name: "Pixel", maxInstances: 3)], store: store)
    }

    private func saved(_ serial: String, pid: Int32?) -> Slot {
        .init(serial: serial, model: "Pixel", pid: pid, state: .free, stateSince: Date(timeIntervalSince1970: 0), generation: 1)
    }

    @Test
    func `a failed listing adopts the slots whose process is alive and keeps the state file`() async throws {
        defer { try? FileManager.default.removeItem(at: url) }
        let h: Harness = harness(saving: [saved("emulator-5554", pid: 10), saved("emulator-5556", pid: 11), saved("emulator-5558", pid: nil)])
        h.backend.failListings()
        h.backend.kill(pid: 11)

        await h.broker.restore()

        #expect(await h.slots().map(\.serial).sorted() == ["emulator-5554", "emulator-5558"])
        #expect(StateStore(url: url).load().map(\.serial).sorted() == ["emulator-5554", "emulator-5558"])
    }

    @Test
    func `a failed listing never turns the saved slots into an empty state file`() async throws {
        defer { try? FileManager.default.removeItem(at: url) }
        let h: Harness = harness(saving: [saved("emulator-5554", pid: 10)])
        h.backend.failListings()

        await h.broker.restore()

        #expect(StateStore(url: url).load().map(\.serial) == ["emulator-5554"])
    }

    @Test
    func `a working listing adopts only the listed slots`() async throws {
        defer { try? FileManager.default.removeItem(at: url) }
        let h: Harness = harness(saving: [saved("emulator-5554", pid: 10), saved("emulator-5556", pid: 11)])
        h.backend.setLive(["emulator-5554"])

        await h.broker.restore()

        #expect(await h.slots().map(\.serial) == ["emulator-5554"])
    }
}
