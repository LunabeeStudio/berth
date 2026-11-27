import BerthCore

public protocol IOSDeviceSource: Sendable {
    /// The iOS devices plugged in over USB, or nil when the poll failed.
    func devices() async -> [IOSDevice]?
}
