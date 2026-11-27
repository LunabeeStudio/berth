import Foundation

enum LockdownKey: String {
    static let port: UInt16 = 62078

    case deviceName = "DeviceName"
    case productType = "ProductType"
    case productVersion = "ProductVersion"

    /// A reply carrying an `Error` instead of a `Value` (key absent, locked-down phone) is no value, not a failure.
    static func value(in payload: Data) throws -> String? {
        try PropertyList.dictionary(from: payload)["Value"] as? String
    }

    func payload() throws -> Data {
        try PropertyList.data(from: ["Label": "berth", "Request": "GetValue", "Key": rawValue])
    }
}
