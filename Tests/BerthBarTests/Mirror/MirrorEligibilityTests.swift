import Testing

@testable import BerthBar
@testable import BerthCore

@Suite
struct MirrorEligibilityTests {
    private let pool: [PoolEntry] = [
        .init(name: "Pixel_9", platform: .android, maxInstances: 2),
        .init(name: "iPhone 16", platform: .ios, maxInstances: 2)
    ]

    @Test(arguments: [SlotState.free, .leased])
    func `headless android slot in a mirrorable state shows the button`(state: SlotState) {
        let slot: Slot = .mock(model: "Pixel_9", state: state)

        #expect(MirrorEligibility.showsMirrorButton(slot, pool: pool))
    }

    @Test(arguments: [SlotState.booting, .resetting, .stopping])
    func `no button while the slot is not free or leased`(state: SlotState) {
        let slot: Slot = .mock(model: "Pixel_9", state: state)

        #expect(!MirrorEligibility.showsMirrorButton(slot, pool: pool))
    }

    @Test
    func `no button on a windowed slot`() {
        let slot: Slot = .mock(model: "Pixel_9", state: .free, windowed: true)

        #expect(!MirrorEligibility.showsMirrorButton(slot, pool: pool))
    }

    @Test
    func `no button on an ios simulator`() {
        let slot: Slot = .mock(model: "iPhone 16", state: .free)

        #expect(!MirrorEligibility.showsMirrorButton(slot, pool: pool))
    }

    @Test
    func `a model missing from the pool counts as android`() {
        let slot: Slot = .mock(model: "Unknown", state: .free)

        #expect(MirrorEligibility.showsMirrorButton(slot, pool: []))
    }
}
