import Foundation

public struct IOSDevice: Codable, Sendable, Hashable, Identifiable {
    public let udid: String
    public let name: String?
    public let productType: String?
    public let osVersion: String?
    public let trusted: Bool

    public var id: String { udid }

    public init(udid: String, name: String?, productType: String?, osVersion: String?, trusted: Bool) {
        self.udid = udid
        self.name = name
        self.productType = productType
        self.osVersion = osVersion
        self.trusted = trusted
    }
}

extension IOSDevice {
    static func mock(
        udid: String = "00008030-001A2B3C4D5E802E",
        name: String? = "Lunabee iPhone",
        productType: String? = "iPhone10,6",
        osVersion: String? = "16.5.1",
        trusted: Bool = true
    ) -> IOSDevice {
        .init(udid: udid, name: name, productType: productType, osVersion: osVersion, trusted: trusted)
    }
}
