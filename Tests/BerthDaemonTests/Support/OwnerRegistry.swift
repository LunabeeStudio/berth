import BerthCore
@testable import BerthDaemon
import Foundation
import Synchronization
import Testing

final class OwnerRegistry: Sendable {
    private let dead = Mutex<Set<Int32>>([])
    func kill(_ pid: Int32) { dead.withLock { _ = $0.insert(pid) } }
    func isAlive(_ owner: Owner) -> Bool { !dead.withLock { $0.contains(owner.pid) } }
}
