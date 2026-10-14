import BerthCore
@testable import BerthDaemon
import Foundation
import Testing

@Suite
struct BrokerStopRaceTests {
    @Test
    func `device that finishes resetting after stop-all is shut down again`() async throws {
        let h = Harness(maxRunning: 1, pool: [PoolEntry(name: "iPhone 17", platform: .ios, maxInstances: 1)])
        let client = await h.claim(platform: .ios)
        try await eventually { client.grant != nil }
        let serial = try #require(client.grant?.serial)

        h.backend.holdResets(true)
        _ = await h.broker.release(serial)
        try await eventually { await h.slots().map(\.state) == [.resetting] }
        _ = await h.broker.stopAll()
        try await eventually { await h.slots().isEmpty }
        let shutdownsBefore = h.backend.shutdowns.count

        h.backend.holdResets(false)
        try await eventually { h.backend.shutdowns.count > shutdownsBefore }
        try await eventually { !h.backend.isLive(serial) }
        #expect(await h.slots().isEmpty)
    }
}
