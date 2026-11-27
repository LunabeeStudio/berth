import BerthCore

enum DeviceClipboardError: Error, CustomStringConvertible, Equatable {
    case scrcpyNotFound
    case serverNotFound
    case timedOut(serial: String)
    case failed(line: String)

    var description: String {
        switch self {
        case .scrcpyNotFound: ScrcpyMirror.notFoundMessage
        case .serverNotFound: "scrcpy server not found, set \(ScrcpyServerLocator.environmentKey)"
        case let .timedOut(serial): "\(serial): clipboard read timed out"
        case let .failed(line): line
        }
    }
}
