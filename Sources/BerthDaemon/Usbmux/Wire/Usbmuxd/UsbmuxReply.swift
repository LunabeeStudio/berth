import Foundation

enum UsbmuxReply {
    /// USB devices only: usbmuxd also lists phones it reaches over Wi-Fi sync.
    static func usbDevices(in payload: Data) throws -> [UsbmuxDevice] {
        guard let entries = try PropertyList.dictionary(from: payload)["DeviceList"] as? [[String: Any]] else {
            throw UsbmuxError.malformedReply
        }
        return entries.compactMap { entry in
            guard
                let deviceID = entry["DeviceID"] as? Int,
                let properties = entry["Properties"] as? [String: Any],
                properties["ConnectionType"] as? String == "USB",
                let udid = properties["SerialNumber"] as? String
            else {
                return nil
            }
            return UsbmuxDevice(deviceID: deviceID, udid: udid)
        }
    }

    static func isTrusted(pairRecord payload: Data) throws -> Bool {
        let reply: [String: Any] = try PropertyList.dictionary(from: payload)
        if reply["PairRecordData"] is Data { return true }
        guard let code = reply["Number"] as? Int, code != 0 else { throw UsbmuxError.malformedReply }
        return false
    }

    static func requireSuccess(result payload: Data) throws {
        let reply: [String: Any] = try PropertyList.dictionary(from: payload)
        guard let code = reply["Number"] as? Int else { throw UsbmuxError.malformedReply }
        guard code == 0 else { throw UsbmuxError.rejected(code: code) }
    }
}
