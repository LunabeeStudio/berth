import BerthCore
@testable import BerthDaemon
import Foundation
import Synchronization
import Testing

final class TestClock: Sendable {
    private let current = Mutex(Date(timeIntervalSince1970: 1_000_000))
    var now: Date { current.withLock { $0 } }
    func advance(_ seconds: TimeInterval) { current.withLock { $0 = $0.addingTimeInterval(seconds) } }
}
