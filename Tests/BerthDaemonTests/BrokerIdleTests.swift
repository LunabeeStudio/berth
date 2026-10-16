import BerthCore
import Testing

@testable import BerthDaemon

@Suite
struct BrokerIdleTests {
    @Test
    func `idle with nothing running`() async {
        let h: Harness = .init()

        #expect(await h.broker.isIdle)
    }

    @Test
    func `not idle while a lease is held and idle again after release`() async throws {
        let h: Harness = .init()
        let client: Client = await h.claim()
        try await eventually { client.grant != nil }
        #expect(await !h.broker.isIdle)

        _ = await h.broker.release("emulator-5554")

        try await eventually { await h.broker.isIdle }
    }

    @Test
    func `not idle while a claim waits`() async throws {
        let h: Harness = .init(maxRunning: 1)
        let holder: Client = await h.claim(pid: 1)
        try await eventually { holder.grant != nil }
        _ = await h.claim(pid: 2)

        _ = await h.broker.release("emulator-5554")

        #expect(await !h.broker.isIdle)
    }
}
