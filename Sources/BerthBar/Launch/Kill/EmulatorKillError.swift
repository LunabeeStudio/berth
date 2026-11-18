enum EmulatorKillError: Error, CustomStringConvertible {
    case timedOut(serial: String)
    case failed(serial: String, stderr: String)

    var description: String {
        switch self {
        case let .timedOut(serial): "kill \(serial) timed out"
        case let .failed(serial, stderr): "kill \(serial) failed: \(stderr)"
        }
    }
}
