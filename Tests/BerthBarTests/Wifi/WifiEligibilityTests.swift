import Testing

@testable import BerthBar
@testable import BerthCore

@Suite
struct WifiEligibilityTests {
    private static let states: [AdbState] = [.device, .offline, .unauthorized, .other("recovery")]

    @Test(arguments: states)
    func `a wifi device shows disconnect in any adb state`(state: AdbState) {
        #expect(WifiEligibility.showsDisconnectButton(.mock(serial: "192.168.100.200:5555", state: state)))
        #expect(WifiEligibility.showsDisconnectButton(.mock(serial: "adb-9A2B3C4D5E._adb-tls-connect._tcp", state: state)))
    }

    @Test(arguments: states)
    func `a usb phone or an emulator shows no disconnect`(state: AdbState) {
        #expect(!WifiEligibility.showsDisconnectButton(.mock(serial: "R3CT312YV5B", state: state)))
        #expect(!WifiEligibility.showsDisconnectButton(.mock(serial: "emulator-5554", state: state)))
    }

    @Test
    func `a usb phone in state device shows switch to wifi`() {
        #expect(WifiEligibility.showsSwitchToWifiButton(.mock(serial: "R3CT312YV5B", state: .device)))
    }

    @Test(arguments: [AdbState.offline, .unauthorized, .other("recovery")])
    func `a usb phone in another state shows no switch to wifi`(state: AdbState) {
        #expect(!WifiEligibility.showsSwitchToWifiButton(.mock(serial: "R3CT312YV5B", state: state)))
    }

    @Test(arguments: states)
    func `an emulator shows no switch to wifi`(state: AdbState) {
        #expect(!WifiEligibility.showsSwitchToWifiButton(.mock(serial: "emulator-5554", state: state)))
    }

    @Test(arguments: ["192.168.100.200:5555", "adb-9A2B3C4D5E._adb-tls-connect._tcp"])
    func `a wifi device shows no switch to wifi`(serial: String) {
        #expect(!WifiEligibility.showsSwitchToWifiButton(.mock(serial: serial, state: .device)))
    }
}
