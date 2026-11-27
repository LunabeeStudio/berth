import Synchronization

@testable import BerthBar

final class FakePairClock: PairClock {
    private let elapsed: Mutex<Duration> = .init(.zero)
    private let blocks: Bool

    init(blocking: Bool = false) {
        blocks = blocking
    }

    func now() -> Duration {
        elapsed.withLock { $0 }
    }

    func advance(_ duration: Duration) {
        elapsed.withLock { $0 += duration }
    }

    func sleep(for duration: Duration) async throws {
        if blocks { try await Task.sleep(for: .seconds(3600)) }
        advance(duration)
    }
}
