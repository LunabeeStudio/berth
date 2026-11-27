@testable import BerthCore
@testable import BerthDaemon
import Foundation
import Testing

@Suite
struct BrokerIOSDevicesTests {
    @Test
    func `iOS devices are published after a reap`() async {
        let source: FakeIOSDeviceSource = .init([.mock()])
        let harness: Harness = .init(iosDevices: source)

        await harness.broker.reap()

        #expect(await harness.broker.snapshot().iosDevices == [.mock()])
    }

    @Test
    func `without a source the list stays empty`() async {
        let harness: Harness = .init()

        await harness.broker.reap()

        #expect(await harness.broker.snapshot().iosDevices.isEmpty)
    }

    @Test
    func `a failed poll keeps the last list`() async {
        let source: FakeIOSDeviceSource = .init([.mock()])
        let harness: Harness = .init(iosDevices: source)
        await harness.broker.reap()

        source.set(nil)
        await harness.broker.reap()

        #expect(await harness.broker.snapshot().iosDevices == [.mock()])
    }

    @Test
    func `an unplugged phone leaves the list and watchers are told`() async throws {
        let source: FakeIOSDeviceSource = .init([.mock()])
        let harness: Harness = .init(iosDevices: source)
        await harness.broker.reap()
        let watcher: Client = .init()
        await harness.broker.watch(conn: watcher.conn, sink: watcher.sink)

        source.set([])
        await harness.broker.reap()

        #expect(await harness.broker.snapshot().iosDevices.isEmpty)
        try await eventually { watcher.snapshots.last?.iosDevices.isEmpty == true }
    }

    @Test
    func `a changed trust state notifies watchers`() async throws {
        let source: FakeIOSDeviceSource = .init([.mock(trusted: false)])
        let harness: Harness = .init(iosDevices: source)
        await harness.broker.reap()
        let watcher: Client = .init()
        await harness.broker.watch(conn: watcher.conn, sink: watcher.sink)

        source.set([.mock(trusted: true)])
        await harness.broker.reap()

        try await eventually { watcher.snapshots.last?.iosDevices.first?.trusted == true }
    }

    @Test
    func `android devices are still published when the iOS poll fails`() async {
        let source: FakeIOSDeviceSource = .init(nil)
        let harness: Harness = .init(iosDevices: source)
        harness.backend.attach([.mock()])

        await harness.broker.reap()

        let snapshot: StateSnapshot = await harness.broker.snapshot()
        #expect(snapshot.devices == [.mock()])
        #expect(snapshot.iosDevices.isEmpty)
    }

    @Test
    func `iOS devices are still published when the android listing fails`() async {
        let source: FakeIOSDeviceSource = .init([.mock()])
        let harness: Harness = .init(iosDevices: source)
        harness.backend.failListings()

        await harness.broker.reap()

        #expect(await harness.broker.snapshot().iosDevices == [.mock()])
    }

    @Test
    func `iOS devices never become slots or grants`() async throws {
        let phone: IOSDevice = .mock()
        let harness: Harness = .init(maxRunning: 1, iosDevices: FakeIOSDeviceSource([phone]))
        await harness.broker.reap()

        let client: Client = await harness.claim()
        try await eventually { client.grant != nil }
        let udidClient: Client = await harness.claim(model: phone.udid, pid: 200)
        try await eventually { udidClient.failure != nil }

        let snapshot: StateSnapshot = await harness.broker.snapshot()
        #expect(snapshot.slots.map(\.serial) == ["emulator-5554"])
        #expect(client.grant?.serial == "emulator-5554")
        #expect(udidClient.grant == nil)
        #expect(snapshot.iosDevices == [phone])
    }

    @Test
    func `restore fills the list`() async {
        let harness: Harness = .init(iosDevices: FakeIOSDeviceSource([.mock()]))

        await harness.broker.restore()

        #expect(await harness.broker.snapshot().iosDevices == [.mock()])
    }
}
