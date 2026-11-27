import Foundation

enum UsbmuxMessage {
    case listDevices
    case readPairRecord(udid: String)
    case connect(deviceID: Int, port: UInt16)

    func payload() throws -> Data {
        var fields: [String: Any] = ["ClientVersionString": "berth", "ProgName": "berth"]
        switch self {
        case .listDevices:
            fields["MessageType"] = "ListDevices"
        case let .readPairRecord(udid):
            fields["MessageType"] = "ReadPairRecord"
            fields["PairRecordID"] = udid
        case let .connect(deviceID, port):
            fields["MessageType"] = "Connect"
            fields["DeviceID"] = deviceID
            fields["PortNumber"] = Int(port.bigEndian)
        }
        return try PropertyList.data(from: fields)
    }
}
