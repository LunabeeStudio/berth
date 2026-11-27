@testable import BerthDaemon
import Foundation
import Synchronization

final class FakeUsbmuxConnection: UsbmuxConnection, Sendable {
    private let pending: Mutex<Data>
    private let written: Mutex<[Data]> = .init([])

    var sent: [Data] { written.withLock { $0 } }

    init(replies: [Data] = []) {
        pending = .init(replies.reduce(Data(), +))
    }

    func send(_ data: Data) throws {
        written.withLock { $0.append(data) }
    }

    func receive(count: Int) throws -> Data {
        try pending.withLock { buffer in
            guard buffer.count >= count else { throw UsbmuxError.closed }
            defer { buffer.removeFirst(count) }
            return Data(buffer.prefix(count))
        }
    }
}
