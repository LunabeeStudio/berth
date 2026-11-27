enum WifiAdbError: Error, CustomStringConvertible, Equatable {
    case timedOut(command: String)
    case failed(line: String)
    case noWifiAddress(serial: String)

    var description: String {
        switch self {
        case let .timedOut(command): "adb \(command) timed out"
        case let .failed(line): line
        case let .noWifiAddress(serial): "\(serial): no Wi-Fi address, turn Wi-Fi on"
        }
    }
}
