import Testing

@testable import BerthBar
@testable import BerthCore

@Suite
struct MenuBarLabelTests {
    private static func slots(_ states: [SlotState]) -> [Slot] {
        states.enumerated().map { index, state in
            .mock(serial: "emulator-\(5554 + index * 2)", state: state, lease: state == .leased ? .mock() : nil)
        }
    }

    private static func live(_ states: [SlotState], queue: Int = 0) -> StatusState {
        .live(.mock(slots: slots(states), queue: (0..<queue).map { .mock(id: "w\($0)") }))
    }

    @Test
    func `no slots and no queue reads 0 over 0`() {
        #expect(MenuBarLabel.text(for: Self.live([])) == "0/0")
    }

    @Test
    func `one leased slot reads 1 over 1`() {
        #expect(MenuBarLabel.text(for: Self.live([.leased])) == "1/1")
    }

    @Test
    func `waiting claims append the queue length`() {
        #expect(MenuBarLabel.text(for: Self.live([.leased, .leased, .free], queue: 1)) == "2/3 +1")
    }

    @Test
    func `only leased slots count as leased`() {
        #expect(MenuBarLabel.text(for: Self.live([.booting, .free])) == "0/2")
    }

    @Test
    func `disconnected shows no count`() {
        #expect(MenuBarLabel.text(for: .disconnected("down")) == nil)
    }

    @Test
    func `connecting shows no count`() {
        #expect(MenuBarLabel.text(for: .connecting) == nil)
    }
}
