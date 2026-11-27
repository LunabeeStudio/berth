import Testing

@testable import BerthBar
@testable import BerthCore

@Suite
struct PhysicalDeviceWifiTests {
    @Test(arguments: ["192.168.100.200:5555", "10.0.0.2:37045", "adb-9A2B3C4D5E._adb-tls-connect._tcp"])
    func `an ip with port or an mdns connect name is a wifi serial`(serial: String) {
        #expect(PhysicalDevice.mock(serial: serial).isWifi)
    }

    @Test(arguments: ["R3CT312YV5B", "emulator-5554", "192.168.100.200", "192.168.100:5555", "192.168.100.200:", "192.168.a.200:5555", "localhost:5555", ""])
    func `a usb or emulator serial is not a wifi serial`(serial: String) {
        #expect(!PhysicalDevice.mock(serial: serial).isWifi)
    }
}
