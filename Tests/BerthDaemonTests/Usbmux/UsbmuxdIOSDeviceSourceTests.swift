@testable import BerthCore
@testable import BerthDaemon
import Testing

@Suite
struct UsbmuxdIOSDeviceSourceTests {
    private let iPhone: LockdownValues = .init(name: "Lunabee iPhone", productType: "iPhone10,6", osVersion: "16.5.1")

    @Test
    func `a plugged iPhone is listed with its lockdown values and trust`() async {
        let service: FakeUsbmuxService = .init(devices: [UsbmuxDevice(deviceID: 7, udid: "U1")])
        service.trust("U1")
        service.setLockdown(iPhone, deviceID: 7)
        let source: UsbmuxdIOSDeviceSource = .init(service: service)

        let devices: [IOSDevice]? = await source.devices()

        #expect(devices == [IOSDevice(udid: "U1", name: "Lunabee iPhone", productType: "iPhone10,6", osVersion: "16.5.1", trusted: true)])
    }

    @Test
    func `no phone plugged is an empty list, not a failure`() async {
        let source: UsbmuxdIOSDeviceSource = .init(service: FakeUsbmuxService(devices: []))

        #expect(await source.devices() == [])
    }

    @Test
    func `a phone without a pair record is not trusted`() async {
        let service: FakeUsbmuxService = .init(devices: [UsbmuxDevice(deviceID: 7, udid: "U1")])
        service.setLockdown(iPhone, deviceID: 7)
        let source: UsbmuxdIOSDeviceSource = .init(service: service)

        #expect(await source.devices()?.first?.trusted == false)
    }

    @Test
    func `lockdown is asked once per attachment across polls`() async {
        let service: FakeUsbmuxService = .init(devices: [UsbmuxDevice(deviceID: 7, udid: "U1")])
        service.setLockdown(iPhone, deviceID: 7)
        let source: UsbmuxdIOSDeviceSource = .init(service: service)

        _ = await source.devices()
        _ = await source.devices()

        #expect(service.lockdownCalls == [7])
    }

    @Test
    func `trust is read on every poll`() async {
        let service: FakeUsbmuxService = .init(devices: [UsbmuxDevice(deviceID: 7, udid: "U1")])
        service.setLockdown(iPhone, deviceID: 7)
        let source: UsbmuxdIOSDeviceSource = .init(service: service)

        let before: Bool? = await source.devices()?.first?.trusted
        service.trust("U1")
        let after: Bool? = await source.devices()?.first?.trusted

        #expect(before == false)
        #expect(after == true)
    }

    @Test
    func `a re-attached phone with a new DeviceID is asked again`() async {
        let service: FakeUsbmuxService = .init(devices: [UsbmuxDevice(deviceID: 7, udid: "U1")])
        service.setLockdown(iPhone, deviceID: 7)
        service.setLockdown(iPhone, deviceID: 8)
        let source: UsbmuxdIOSDeviceSource = .init(service: service)

        _ = await source.devices()
        service.attach([])
        _ = await source.devices()
        service.attach([UsbmuxDevice(deviceID: 8, udid: "U1")])
        _ = await source.devices()

        #expect(service.lockdownCalls == [7, 8])
    }

    @Test
    func `a lockdown failure keeps the row with empty values and is not retried`() async {
        let service: FakeUsbmuxService = .init(devices: [UsbmuxDevice(deviceID: 7, udid: "U1")])
        let source: UsbmuxdIOSDeviceSource = .init(service: service)

        let first: [IOSDevice]? = await source.devices()
        let second: [IOSDevice]? = await source.devices()

        #expect(first == [IOSDevice(udid: "U1", name: nil, productType: nil, osVersion: nil, trusted: false)])
        #expect(second == first)
        #expect(service.lockdownCalls == [7])
    }

    @Test
    func `a usbmuxd failure is a failed poll`() async {
        let source: UsbmuxdIOSDeviceSource = .init(service: FakeUsbmuxService(devices: nil))

        #expect(await source.devices() == nil)
    }

    @Test
    func `a missing socket is a failed poll`() async {
        let source: UsbmuxdIOSDeviceSource = .init(socketPath: "/nonexistent/usbmuxd")

        #expect(await source.devices() == nil)
    }

    @Test
    func `two USB entries sharing a udid list one row`() async {
        let service: FakeUsbmuxService = .init(devices: [UsbmuxDevice(deviceID: 7, udid: "U1"), UsbmuxDevice(deviceID: 8, udid: "U1")])
        service.setLockdown(iPhone, deviceID: 7)
        let source: UsbmuxdIOSDeviceSource = .init(service: service)

        let devices: [IOSDevice]? = await source.devices()

        #expect(devices?.map(\.udid) == ["U1"])
        #expect(devices?.first?.name == "Lunabee iPhone")
    }
}
