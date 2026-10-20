import BerthCore

enum MirrorError: Error, Equatable, CustomStringConvertible {
    case notABerthDevice(String)
    case notLeased(serial: String, state: SlotState)
    case scrcpyNotFound
    case deviceHubNotFound
    case failed(serial: String, reason: String)

    var description: String {
        switch self {
        case let .notABerthDevice(serial): "\(serial) is not a berth device"
        case let .notLeased(serial, state): "\(serial) is \(state.rawValue), claim it first"
        case .scrcpyNotFound: ScrcpyMirror.notFoundMessage
        case .deviceHubNotFound: "DeviceHub not found: needs Xcode 27"
        case let .failed(serial, reason): "mirror \(serial) failed: \(reason)"
        }
    }
}
