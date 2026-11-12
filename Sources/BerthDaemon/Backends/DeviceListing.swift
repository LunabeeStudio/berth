import BerthCore

public struct DeviceListing: Sendable, Equatable {
    public var live: Set<String>
    public var devices: [PhysicalDevice]

    public init(live: Set<String> = [], devices: [PhysicalDevice] = []) {
        self.live = live
        self.devices = devices
    }

    /// Parses `adb devices -l`: emulators feed `live`, every other entry is a physical device.
    public static func parse(adbDevices output: String) -> DeviceListing {
        var listing: DeviceListing = .init()
        for line in output.split(whereSeparator: \.isNewline) where !line.hasPrefix("List of devices") && !line.hasPrefix("*") {
            let fields: [Substring] = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 2 else { continue }
            let serial: String = .init(fields[0])
            if serial.hasPrefix("emulator-") {
                listing.live.insert(serial)
                continue
            }
            let model: String? = fields.dropFirst(2).first { $0.hasPrefix("model:") }.map { .init($0.dropFirst("model:".count)) }
            listing.devices.append(PhysicalDevice(serial: serial, model: model, state: .init(word: String(fields[1]))))
        }
        return listing
    }
}
