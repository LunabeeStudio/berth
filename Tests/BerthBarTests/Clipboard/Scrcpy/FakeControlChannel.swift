import Synchronization

@testable import BerthBar

final class FakeControlChannel: ScrcpyControlChannel, Sendable {
    private let script: Mutex<[ScrcpyReadOutcome]>
    private let writes: Mutex<[[UInt8]]> = .init([])
    private let accepts: Bool

    var written: [[UInt8]] { writes.withLock { $0 } }

    init(_ script: [ScrcpyReadOutcome], acceptsWrites: Bool = true) {
        self.script = .init(script)
        accepts = acceptsWrites
    }

    func write(_ bytes: [UInt8]) -> Bool {
        writes.withLock { $0.append(bytes) }
        return accepts
    }

    func read(until deadline: ContinuousClock.Instant) -> ScrcpyReadOutcome {
        script.withLock { $0.isEmpty ? .timeout : $0.removeFirst() }
    }
}
