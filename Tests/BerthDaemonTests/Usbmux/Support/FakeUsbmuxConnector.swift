@testable import BerthDaemon
import Synchronization

final class FakeUsbmuxConnector: UsbmuxConnecting, Sendable {
    private let connections: Mutex<[FakeUsbmuxConnection]>

    init(_ connections: [FakeUsbmuxConnection]) {
        self.connections = .init(connections)
    }

    func connect() throws -> any UsbmuxConnection {
        try connections.withLock { queue in
            guard !queue.isEmpty else { throw UsbmuxError.unavailable }
            return queue.removeFirst()
        }
    }
}
