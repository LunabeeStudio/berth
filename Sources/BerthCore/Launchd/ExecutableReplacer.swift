import Darwin
import Foundation

public struct ExecutableReplacer: Sendable {
    private let pids: @Sendable (_ executable: String) -> [Int32]
    private let terminate: @Sendable (_ pid: Int32) -> Void
    private let isAlive: @Sendable (_ pid: Int32) -> Bool
    private let sleep: @Sendable (_ interval: Duration) async -> Void

    public init(
        pids: @escaping @Sendable (String) -> [Int32] = ProcessInspector.pids(running:),
        terminate: @escaping @Sendable (Int32) -> Void = { _ = kill($0, SIGTERM) },
        isAlive: @escaping @Sendable (Int32) -> Bool = ProcessInspector.isProcessAlive,
        sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.pids = pids
        self.terminate = terminate
        self.isAlive = isAlive
        self.sleep = sleep
    }

    /// Returns the pids still alive once `timeout` has passed.
    public func stop(executable: String, timeout: Duration = .seconds(5), pollInterval: Duration = .milliseconds(100)) async -> [Int32] {
        var remaining: [Int32] = pids(executable)
        remaining.forEach(terminate)
        var waited: Duration = .zero
        remaining = remaining.filter(isAlive)
        while !remaining.isEmpty, waited < timeout {
            await sleep(pollInterval)
            waited += pollInterval
            remaining = remaining.filter(isAlive)
        }
        return remaining
    }
}
