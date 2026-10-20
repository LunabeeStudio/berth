import BerthCore

enum MirrorResolver {
    static func resolve(serial: String, in snapshot: StateSnapshot) throws -> MirrorTarget {
        guard let slot = snapshot.slots.first(where: { $0.serial == serial }) else {
            throw MirrorError.notABerthDevice(serial)
        }
        guard slot.state == .leased else { throw MirrorError.notLeased(serial: serial, state: slot.state) }
        switch snapshot.pool.platform(of: slot.model) {
        case .android: return .android(serial: slot.serial, model: slot.model)
        case .ios: return .ios(udid: slot.serial)
        }
    }
}
