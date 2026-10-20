import BerthCore

enum MirrorEligibility {
    static func showsMirrorButton(_ slot: Slot, pool: [PoolEntry]) -> Bool {
        guard slot.state == .free || slot.state == .leased else { return false }
        switch pool.platform(of: slot.model) {
        case .android: return !slot.windowed
        case .ios: return true
        }
    }

    static func help(for slot: Slot, pool: [PoolEntry]) -> String {
        switch (pool.platform(of: slot.model), slot.state) {
        case (.android, _): "Mirror"
        case (.ios, .leased): "Mirror in DeviceHub (input reaches the agent's simulator)"
        case (.ios, _): "Mirror in DeviceHub"
        }
    }
}
