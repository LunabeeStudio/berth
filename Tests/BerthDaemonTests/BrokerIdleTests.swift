import BerthCore
import Synchronization
import Testing

@testable import BerthDaemon

@Suite
struct BrokerIdleTests {
    @Test
    func `runs the body when nothing is running`() async {
        let h: Harness = .init()
        let ran: Mutex<Bool> = .init(false)

        let result: Bool = await h.broker.performIfIdle { ran.withLock { $0 = true } }

        #expect(result && ran.withLock { $0 })
    }

    @Test
    func `skips the body while a lease is held and runs it after release`() async throws {
        let h: Harness = .init()
        let client: Client = await h.claim()
        try await eventually { client.grant != nil }
        #expect(await !h.broker.performIfIdle { Issue.record("ran while leased") })

        _ = await h.broker.release("emulator-5554")

        try await eventually { await h.broker.performIfIdle {} }
    }

    @Test
    func `skips the body while a claim waits`() async throws {
        let h: Harness = .init(maxRunning: 1)
        let holder: Client = await h.claim(pid: 1)
        try await eventually { holder.grant != nil }
        _ = await h.claim(pid: 2)

        _ = await h.broker.release("emulator-5554")

        #expect(await !h.broker.performIfIdle { Issue.record("ran while a claim waits") })
    }
}
