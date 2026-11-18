import Testing

@testable import BerthBar
@testable import BerthCore

@Suite
struct KillEligibilityTests {
    @Test(arguments: [AdbState.device, .offline, .unauthorized])
    func `an emulator shows the kill button in any adb state`(state: AdbState) {
        #expect(KillEligibility.showsKillButton(.mock(serial: "emulator-5554", model: "Pixel_9", state: state)))
    }

    @Test(arguments: ["R3CT312YV5B", "192.168.100.200:5555", "adb-9A2B3C4D5E._adb-tls-connect._tcp"])
    func `a phone has no kill button`(serial: String) {
        #expect(!KillEligibility.showsKillButton(.mock(serial: serial)))
    }
}
