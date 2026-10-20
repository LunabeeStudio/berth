import BerthCore
import Foundation
import Testing

@testable import berth

@Suite
struct MirrorResolverTests {
    private static func snapshot(serial: String, model: String, state: SlotState) -> StateSnapshot {
        let slot: Slot = .init(serial: serial, model: model, pid: nil, state: state, stateSince: .init(timeIntervalSince1970: 0), generation: 0)
        let pool: [PoolEntry] = [
            .init(name: "Pixel_9", platform: .android, maxInstances: 1),
            .init(name: "iPhone 17", platform: .ios, maxInstances: 1),
        ]
        return .init(slots: [slot], queue: [], maxRunning: 3, pool: pool, generatedAt: .init(timeIntervalSince1970: 0))
    }

    @Test
    func `leased android emulator resolves to an android target`() throws {
        let snapshot: StateSnapshot = Self.snapshot(serial: "emulator-5554", model: "Pixel_9", state: .leased)

        #expect(try MirrorResolver.resolve(serial: "emulator-5554", in: snapshot) == .android(serial: "emulator-5554", model: "Pixel_9"))
    }

    @Test
    func `leased simulator resolves to an ios target`() throws {
        let snapshot: StateSnapshot = Self.snapshot(serial: "UDID-1", model: "iPhone 17", state: .leased)

        #expect(try MirrorResolver.resolve(serial: "UDID-1", in: snapshot) == .ios(udid: "UDID-1"))
    }

    @Test(arguments: [SlotState.free, .booting, .resetting, .stopping])
    func `a device that is not leased asks to claim it first`(state: SlotState) {
        let snapshot: StateSnapshot = Self.snapshot(serial: "emulator-5554", model: "Pixel_9", state: state)

        #expect(throws: MirrorError.notLeased(serial: "emulator-5554", state: state)) {
            try MirrorResolver.resolve(serial: "emulator-5554", in: snapshot)
        }
    }

    @Test
    func `unknown serial is not a berth device`() {
        let snapshot: StateSnapshot = Self.snapshot(serial: "emulator-5554", model: "Pixel_9", state: .leased)

        #expect(throws: MirrorError.notABerthDevice("foo")) {
            try MirrorResolver.resolve(serial: "foo", in: snapshot)
        }
    }

    @Test
    func `error messages match the documented text`() {
        #expect("\(MirrorError.notABerthDevice("foo"))" == "foo is not a berth device")
        #expect("\(MirrorError.notLeased(serial: "emulator-5554", state: .free))" == "emulator-5554 is free, claim it first")
    }
}
