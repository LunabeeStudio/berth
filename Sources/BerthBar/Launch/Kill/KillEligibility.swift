import BerthCore

enum KillEligibility {
    static func showsKillButton(_ device: PhysicalDevice) -> Bool {
        device.serial.hasPrefix("emulator-")
    }
}
