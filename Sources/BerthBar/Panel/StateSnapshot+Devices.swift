import BerthCore

extension StateSnapshot {
    var hasNoDevices: Bool { devices.isEmpty && iosDevices.isEmpty }
}
