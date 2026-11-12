import Foundation

public struct PhysicalDevice: Codable, Sendable, Hashable, Identifiable {
    public var serial: String
    public var model: String?
    public var state: AdbState

    public var id: String { serial }

    public init(serial: String, model: String?, state: AdbState) {
        self.serial = serial
        self.model = model
        self.state = state
    }
}

extension PhysicalDevice {
    static func mock(serial: String = "R3CT312YV5B", model: String? = "SM_S901B", state: AdbState = .device) -> PhysicalDevice {
        .init(serial: serial, model: model, state: state)
    }
}
