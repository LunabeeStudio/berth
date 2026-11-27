import Synchronization

@testable import BerthBar

final class FakeScrcpyServer: ScrcpyServer {
    private let exitsOnItsOwn: Bool
    private let stops: Mutex<Int> = .init(0)

    var stopCount: Int { stops.withLock { $0 } }

    init(exitsOnItsOwn: Bool = true) {
        self.exitsOnItsOwn = exitsOnItsOwn
    }

    func failureLine() -> String? { nil }

    func stop() async -> Bool {
        stops.withLock { $0 += 1 }
        return exitsOnItsOwn
    }
}
