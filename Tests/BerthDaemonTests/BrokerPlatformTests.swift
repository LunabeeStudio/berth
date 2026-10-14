import BerthCore
@testable import BerthDaemon
import Foundation
import Testing

@Suite
struct BrokerPlatformTests {
    private static let mixedPool = [PoolEntry(name: "Pixel", maxInstances: 1), PoolEntry(name: "iPhone 17", platform: .ios, maxInstances: 1)]

    @Test
    func `default claim never gets an ios slot`() async throws {
        let h = Harness(maxRunning: 2, pool: Self.mixedPool)
        let client = await h.claim()
        try await eventually { client.grant != nil }
        #expect(client.grant?.model == "Pixel")
        #expect(client.grant?.serial.hasPrefix("emulator-") == true)
    }

    @Test
    func `ios claim never gets an android slot`() async throws {
        let h = Harness(maxRunning: 2, pool: Self.mixedPool)
        let android = await h.claim(pid: 1)
        try await eventually { android.grant != nil }
        let ios = await h.claim(platform: .ios, pid: 2)
        try await eventually { ios.grant != nil }
        #expect(ios.grant?.model == "iPhone 17")
        #expect(ios.grant?.serial == "UDID-1")
    }

    @Test
    func `any ios waiter does not take a freed android slot`() async throws {
        let h = Harness(maxRunning: 1, pool: Self.mixedPool)
        let android = await h.claim(pid: 1)
        try await eventually { android.grant != nil }
        let ios = await h.claim(platform: .ios, pid: 2)
        try await eventually { ios.lastPosition == 1 }
        _ = await h.broker.release("emulator-5554")
        try await eventually { ios.grant != nil }
        #expect(ios.grant?.model == "iPhone 17")
    }

    @Test
    func `model and platform mismatch is rejected`() async throws {
        let h = Harness(pool: Self.mixedPool)
        let wrongPlatform = await h.claim(model: "Pixel", platform: .ios)
        try await eventually { wrongPlatform.failure != nil }
        #expect(wrongPlatform.failure?.contains("not in the pool") == true)
        let defaultPlatform = await h.claim(model: "iPhone 17")
        try await eventually { defaultPlatform.failure != nil }
        #expect(defaultPlatform.failure?.contains("not in the pool") == true)
    }

    @Test
    func `ios claim fails when the pool has no simulators`() async throws {
        let h = Harness()
        let client = await h.claim(platform: .ios)
        try await eventually { client.failure != nil }
        #expect(client.failure?.contains("no ios entries") == true)
    }

    @Test
    func `broken simulator fails ios waiters but not android ones`() async throws {
        let h = Harness(maxRunning: 2, pool: Self.mixedPool)
        h.backend.failBoot("iPhone 17")
        let ios = await h.claim(platform: .ios, pid: 1)
        try await eventually { ios.failure != nil }
        let android = await h.claim(pid: 2)
        try await eventually { android.grant != nil }
        #expect(android.failure == nil)
    }
}
