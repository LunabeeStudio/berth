@testable import BerthDaemon
import Foundation
import Testing

@Suite
struct UsbmuxMessageTests {
    @Test
    func `list devices names the client`() throws {
        let fields: [String: Any] = try PropertyList.dictionary(from: UsbmuxMessage.listDevices.payload())

        #expect(fields["MessageType"] as? String == "ListDevices")
        #expect(fields["ClientVersionString"] as? String == "berth")
        #expect(fields["ProgName"] as? String == "berth")
    }

    @Test
    func `read pair record carries the udid`() throws {
        let fields: [String: Any] = try PropertyList.dictionary(from: UsbmuxMessage.readPairRecord(udid: UsbmuxFixtures.udid).payload())

        #expect(fields["MessageType"] as? String == "ReadPairRecord")
        #expect(fields["PairRecordID"] as? String == UsbmuxFixtures.udid)
    }

    @Test
    func `connect sends the lockdown port in network byte order`() throws {
        let fields: [String: Any] = try PropertyList.dictionary(from: UsbmuxMessage.connect(deviceID: 7, port: LockdownKey.port).payload())

        #expect(fields["MessageType"] as? String == "Connect")
        #expect(fields["DeviceID"] as? Int == 7)
        #expect(fields["PortNumber"] as? Int == 0x7EF2)
    }
}
