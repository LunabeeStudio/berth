import Testing

@testable import BerthBar
@testable import BerthCore

@Suite
struct ClipboardEligibilityTests {
    private let pool: [PoolEntry] = [
        .init(name: "Pixel_9", platform: .android, maxInstances: 2),
        .init(name: "iPhone 16", platform: .ios, maxInstances: 2)
    ]

    @Test(arguments: [SlotState.free, .leased])
    func `headless android slot in a readable state shows the button`(state: SlotState) {
        let slot: Slot = .mock(model: "Pixel_9", state: state)

        #expect(ClipboardEligibility.showsCopyButton(slot, pool: pool))
    }

    @Test(arguments: [SlotState.free, .leased])
    func `windowed android slot shows the button too`(state: SlotState) {
        let slot: Slot = .mock(model: "Pixel_9", state: state, windowed: true)

        #expect(ClipboardEligibility.showsCopyButton(slot, pool: pool))
    }

    @Test(arguments: [SlotState.booting, .resetting, .stopping, .preparing])
    func `no button while the android slot is not free or leased`(state: SlotState) {
        let slot: Slot = .mock(model: "Pixel_9", state: state)

        #expect(!ClipboardEligibility.showsCopyButton(slot, pool: pool))
    }

    @Test(arguments: [SlotState.free, .leased])
    func `no button on an ios simulator`(state: SlotState) {
        let slot: Slot = .mock(model: "iPhone 16", state: state)

        #expect(!ClipboardEligibility.showsCopyButton(slot, pool: pool))
    }

    @Test
    func `a model outside the pool counts as android`() {
        let slot: Slot = .mock(model: "Unlisted", state: .free)

        #expect(ClipboardEligibility.showsCopyButton(slot, pool: pool))
    }

    @Test
    func `a device in adb state device shows the button`() {
        #expect(ClipboardEligibility.showsCopyButton(.mock(state: .device)))
    }

    @Test(arguments: [AdbState.offline, .unauthorized])
    func `no button on a device in another adb state`(state: AdbState) {
        #expect(!ClipboardEligibility.showsCopyButton(.mock(state: state)))
    }
}
