import BerthCore
@testable import BerthDaemon
import Foundation
import Synchronization
import Testing

struct Harness {
    let backend = FakeBackend()
    let clock = TestClock()
    let owners = OwnerRegistry()
    let broker: Broker

    init(maxRunning: Int = 2, pool: [PoolEntry] = [PoolEntry(name: "Pixel", maxInstances: 2)], idle: Int = 900) {
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
    func claim(model: String? = nil, platform: Platform? = nil, pid: Int32 = 100, ttl: Int? = nil, windowed: Bool? = nil, acknowledge: Bool = true) async -> Client {
        let client = Client()
        let request: ClaimRequest = .init(
            model: model,
            platform: platform,
            ttl: ttl,
            label: nil,
            owner: Owner(pid: pid, startTime: nil, name: "agent"),
            windowed: windowed
        )
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
