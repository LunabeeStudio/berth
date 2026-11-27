@testable import BerthDaemon
import Foundation
import Testing

@Suite
struct UsbmuxdServiceTests {
    @Test
    func `usb devices sends ListDevices and parses the reply`() throws {
        let connection: FakeUsbmuxConnection = .init(replies: [UsbmuxFraming.frame(UsbmuxFixtures.deviceList)])
        let service: UsbmuxdService = .init(connector: FakeUsbmuxConnector([connection]))

        let devices: [UsbmuxDevice] = try service.usbDevices()

        #expect(devices.map(\.udid) == [UsbmuxFixtures.udid])
        #expect(connection.sent.count == 1)
    }

    @Test
    func `is trusted reads the pair record of the udid`() throws {
        let connection: FakeUsbmuxConnection = .init(replies: [UsbmuxFraming.frame(UsbmuxFixtures.pairRecord)])
        let service: UsbmuxdService = .init(connector: FakeUsbmuxConnector([connection]))

        #expect(try service.isTrusted(udid: UsbmuxFixtures.udid))
    }

    @Test
    func `lockdown values come from one tunnel after Connect`() throws {
        let connection: FakeUsbmuxConnection = .init(replies: [
            UsbmuxFraming.frame(UsbmuxFixtures.result(0)),
            LockdownFraming.frame(UsbmuxFixtures.value("Lunabee iPhone")),
            LockdownFraming.frame(UsbmuxFixtures.value("iPhone10,6")),
            LockdownFraming.frame(UsbmuxFixtures.value("16.5.1"))
        ])
        let service: UsbmuxdService = .init(connector: FakeUsbmuxConnector([connection]))

        let values: LockdownValues = try service.lockdownValues(deviceID: 7)

        #expect(values == LockdownValues(name: "Lunabee iPhone", productType: "iPhone10,6", osVersion: "16.5.1"))
        #expect(connection.sent.count == 4)
    }

    @Test
    func `a refused Connect fails the lockdown read`() {
        let connection: FakeUsbmuxConnection = .init(replies: [UsbmuxFraming.frame(UsbmuxFixtures.result(3))])
        let service: UsbmuxdService = .init(connector: FakeUsbmuxConnector([connection]))

        #expect(throws: UsbmuxError.rejected(code: 3)) { try service.lockdownValues(deviceID: 7) }
    }

    @Test
    func `a lockdown error reply leaves that value empty`() throws {
        let connection: FakeUsbmuxConnection = .init(replies: [
            UsbmuxFraming.frame(UsbmuxFixtures.result(0)),
            LockdownFraming.frame(UsbmuxFixtures.value("Lunabee iPhone")),
            LockdownFraming.frame(UsbmuxFixtures.lockdownError),
            LockdownFraming.frame(UsbmuxFixtures.value("16.5.1"))
        ])
        let service: UsbmuxdService = .init(connector: FakeUsbmuxConnector([connection]))

        let values: LockdownValues = try service.lockdownValues(deviceID: 7)

        #expect(values == LockdownValues(name: "Lunabee iPhone", productType: nil, osVersion: "16.5.1"))
    }
}
