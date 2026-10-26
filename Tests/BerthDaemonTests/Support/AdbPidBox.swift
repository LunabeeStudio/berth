import Synchronization

final class AdbPidBox: Sendable {
    private let state: Mutex<(pid: Int32?, reads: Int)> = .init((nil, 0))

    var value: Int32? {
        get {
            state.withLock {
                $0.reads += 1
                return $0.pid
            }
        }
        set { state.withLock { $0.pid = newValue } }
    }

    var reads: Int { state.withLock { $0.reads } }
}
