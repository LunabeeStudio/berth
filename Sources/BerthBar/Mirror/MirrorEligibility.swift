import BerthCore

enum MirrorEligibility {
    static func showsMirrorButton(_ slot: Slot, pool: [PoolEntry]) -> Bool {
        return pool.platform(of: slot.model) == .android && !slot.windowed && (slot.state == .free || slot.state == .leased)
    }
}
