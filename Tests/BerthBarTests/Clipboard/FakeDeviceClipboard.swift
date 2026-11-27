import Synchronization

@testable import BerthBar

final class FakeDeviceClipboard: DeviceClipboard {
    private let outcome: Mutex<Result<String?, DeviceClipboardError>>
    private let serials: Mutex<[String]> = .init([])

    var requestedSerials: [String] { serials.withLock { $0 } }

    init(_ outcome: Result<String?, DeviceClipboardError>) {
        self.outcome = .init(outcome)
    }

    func text(serial: String) async throws -> String? {
        serials.withLock { $0.append(serial) }
        return try outcome.withLock { $0 }.get()
    }

    func update(_ outcome: Result<String?, DeviceClipboardError>) {
        self.outcome.withLock { $0 = outcome }
    }
}
