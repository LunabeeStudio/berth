@testable import BerthDaemon
import Foundation
import Testing

@Suite
struct UsbmuxReplyTests {
    @Test
    func `list devices keeps the USB device and drops the Network one`() throws {
        let devices: [UsbmuxDevice] = try UsbmuxReply.usbDevices(in: UsbmuxFixtures.deviceList)

        #expect(devices == [UsbmuxDevice(deviceID: 7, udid: UsbmuxFixtures.udid)])
    }

    @Test
    func `list devices without a DeviceList is malformed`() {
        #expect(throws: UsbmuxError.malformedReply) { try UsbmuxReply.usbDevices(in: UsbmuxFixtures.result(0)) }
    }

    @Test
    func `a payload that is no plist is malformed`() {
        #expect(throws: UsbmuxError.malformedReply) { try UsbmuxReply.usbDevices(in: Data("nope".utf8)) }
    }

    @Test
    func `a pair record means trusted`() throws {
        #expect(try UsbmuxReply.isTrusted(pairRecord: UsbmuxFixtures.pairRecord))
    }

    @Test
    func `an error number for the pair record means not trusted`() throws {
        #expect(try !UsbmuxReply.isTrusted(pairRecord: UsbmuxFixtures.result(2)))
    }

    @Test
    func `a result of zero is a success`() throws {
        try UsbmuxReply.requireSuccess(result: UsbmuxFixtures.result(0))
    }

    @Test
    func `a non-zero result is rejected with its code`() {
        #expect(throws: UsbmuxError.rejected(code: 3)) { try UsbmuxReply.requireSuccess(result: UsbmuxFixtures.result(3)) }
    }
}
