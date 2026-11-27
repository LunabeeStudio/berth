import BerthCore

enum ClipboardEligibility {
    static func showsCopyButton(_ slot: Slot, pool: [PoolEntry]) -> Bool {
        guard slot.state == .free || slot.state == .leased else { return false }
        return pool.platform(of: slot.model) == .android
    }

    static func showsCopyButton(_ device: PhysicalDevice) -> Bool {
        device.state == .device
    }
}
