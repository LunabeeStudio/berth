import BerthCore
import Testing

@testable import BerthBar

@Suite
struct AVDMenuItemsTests {
    private static let pool: [PoolEntry] = [
        .init(name: "Pixel_9", maxInstances: 2),
        .init(name: "Pixel_8", maxInstances: 2),
        .init(name: "iPhone 17", platform: .ios, maxInstances: 1)
    ]

    private static let avds: [AVD] = [
        .init(name: "Pixel_9", prepared: true),
        .init(name: "Pixel_8", prepared: false),
        .init(name: "Pixel_10", prepared: true),
        .init(name: "Fresh", prepared: false)
    ]

    @Test
    func `launch lists every AVD sorted, marking unprepared ones and pool membership`() {
        let items: AVDMenuItems = .init(avds: Self.avds, pool: Self.pool)

        #expect(items.launch == [
            .init(name: "Fresh", title: "Fresh (not prepared)", inPool: false),
            .init(name: "Pixel_8", title: "Pixel_8 (not prepared)", inPool: true),
            .init(name: "Pixel_9", title: "Pixel_9", inPool: true),
            .init(name: "Pixel_10", title: "Pixel_10", inPool: false)
        ])
    }

    @Test
    func `prepare lists AVDs that are not both in the pool and prepared`() {
        let items: AVDMenuItems = .init(avds: Self.avds, pool: Self.pool)

        #expect(items.prepare == ["Fresh", "Pixel_8", "Pixel_10"])
    }

    @Test
    func `an iOS pool entry never makes an AVD a pool AVD`() {
        let items: AVDMenuItems = .init(avds: [.init(name: "iPhone 17", prepared: true)], pool: Self.pool)

        #expect(items.launch.first?.inPool == false)
        #expect(items.prepare == ["iPhone 17"])
    }

    @Test
    func `no AVDs gives no menu items`() {
        let items: AVDMenuItems = .init(avds: [], pool: Self.pool)

        #expect(items.launch.isEmpty)
        #expect(items.prepare.isEmpty)
    }
}
