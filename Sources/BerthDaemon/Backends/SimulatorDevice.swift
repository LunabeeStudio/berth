import Foundation

public struct SimulatorDevice: Sendable, Equatable {
    public var udid: String
    public var name: String
    public var isBooted: Bool

    public var isBerthOwned: Bool { name.hasPrefix(IOSSimulatorBackend.namePrefix) }
}
