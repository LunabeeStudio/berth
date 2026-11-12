import BerthCore
@testable import BerthDaemon
import Testing

@Suite
struct DeviceListingTests {
    @Test
    func `usb device carries its model`() {
        let output: String = """
        List of devices attached
        R3CT312YV5B            device usb:1-1 product:e1sxeea model:SM_S901B device:e1s transport_id:3

        """

        let listing: DeviceListing = .parse(adbDevices: output)

        #expect(listing.devices == [PhysicalDevice(serial: "R3CT312YV5B", model: "SM_S901B", state: .device)])
        #expect(listing.live.isEmpty)
    }

    @Test
    func `unauthorized device has no model`() {
        let output: String = "List of devices attached\nABC123   unauthorized usb:1-1 transport_id:4\n"

        let listing: DeviceListing = .parse(adbDevices: output)

        #expect(listing.devices == [PhysicalDevice(serial: "ABC123", model: nil, state: .unauthorized)])
    }

    @Test
    func `wifi serials are physical devices`() {
        let output: String = """
        List of devices attached
        192.168.1.20:5555      device product:p model:Pixel_8 device:d transport_id:5
        adb-XYZ-abc._adb-tls-connect._tcp device product:p model:Pixel_9 device:d transport_id:6
        """

        let listing: DeviceListing = .parse(adbDevices: output)

        #expect(listing.devices.map(\.serial) == ["192.168.1.20:5555", "adb-XYZ-abc._adb-tls-connect._tcp"])
        #expect(listing.devices.map(\.model) == ["Pixel_8", "Pixel_9"])
    }

    @Test
    func `emulators feed live serials and are not devices`() {
        let output: String = """
        * daemon started successfully
        List of devices attached
        emulator-5554          device product:sdk model:sdk_gphone device:emu transport_id:1
        R3CT312YV5B            offline transport_id:3
        """

        let listing: DeviceListing = .parse(adbDevices: output)

        #expect(listing.live == ["emulator-5554"])
        #expect(listing.devices == [PhysicalDevice(serial: "R3CT312YV5B", model: nil, state: .offline)])
    }

    @Test
    func `header only lists nothing`() {
        #expect(DeviceListing.parse(adbDevices: "List of devices attached\n\n") == DeviceListing())
    }
}
