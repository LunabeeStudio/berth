import BerthCore
@testable import BerthDaemon
import Foundation
import Testing

@Suite
struct DeviceRouterTests {
    private static let config = Config(pool: [PoolEntry(name: "Pixel", maxInstances: 1), PoolEntry(name: "iPhone 17", platform: .ios, maxInstances: 1)])

    private func router(android: FakeBackend = FakeBackend(), ios: FakeBackend = FakeBackend()) -> DeviceRouter {
        DeviceRouter(config: Self.config, android: android, ios: ios)
    }

    @Test
    func `routes shutdown by serial shape`() async {
        let android = FakeBackend()
        let ios = FakeBackend()
        let router = router(android: android, ios: ios)
        await router.shutdown(serial: "emulator-5554", pid: nil)
        await router.shutdown(serial: "UDID-1", pid: nil)
        #expect(android.shutdowns == ["emulator-5554"])
        #expect(ios.shutdowns == ["UDID-1"])
    }

    @Test
    func `live serials are the union of both platforms`() async throws {
        let android = FakeBackend()
        let ios = FakeBackend()
        _ = try await android.launch(serial: "emulator-5554", model: "Pixel", windowed: false)
        _ = try await ios.launch(serial: "UDID-1", model: "iPhone 17", windowed: false)
        #expect(await router(android: android, ios: ios).liveSerials() == ["emulator-5554", "UDID-1"])
    }

    @Test
    func `live serials are unknown when one platform is unknown`() async {
        let ios = NilLiveBackend()
        let router = DeviceRouter(config: Self.config, android: FakeBackend(), ios: ios)
        #expect(await router.liveSerials() == nil)
    }

    @Test
    func `only platforms present in the pool are queried`() async {
        let config = Config(pool: [PoolEntry(name: "Pixel", maxInstances: 1)])
        let router = DeviceRouter(config: config, android: FakeBackend(), ios: NilLiveBackend())
        #expect(await router.liveSerials() == [])
    }
}
