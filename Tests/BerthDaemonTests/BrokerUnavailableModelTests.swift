import BerthCore
@testable import BerthDaemon
import Foundation
import Testing

@Suite
struct BrokerUnavailableModelTests {
    private static let pool = [PoolEntry(name: "Pixel", maxInstances: 1), PoolEntry(name: "iPhone Bogus", platform: .ios, maxInstances: 1)]

    @Test
    func `claim for a model the backend cannot provide fails immediately`() async throws {
        let h = Harness(pool: Self.pool)
        h.backend.markUnavailable("iPhone Bogus", reason: "Invalid device type")
        let client = await h.claim(model: "iPhone Bogus", platform: .ios)
        try await eventually { client.failure != nil }
        #expect(client.failure?.contains("Invalid device type") == true)
    }

    @Test
    func `any ios claim fails when every simulator is unavailable`() async throws {
        let h = Harness(pool: Self.pool)
        h.backend.markUnavailable("iPhone Bogus", reason: "Invalid device type")
        let client = await h.claim(platform: .ios)
        try await eventually { client.failure != nil }
        #expect(client.failure?.contains("Invalid device type") == true)
    }
}
