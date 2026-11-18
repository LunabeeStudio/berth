import Synchronization

@testable import BerthBar

final class FakeEmulatorKiller: EmulatorKiller {
    private struct KillFailed: Error, CustomStringConvertible {
        let description: String
    }

    private let state: Mutex<State> = .init(State())

    private struct State {
        var failure: String?
        var killed: [String] = []
    }

    init(failure: String? = nil) {
        state.withLock { $0.failure = failure }
    }

    func succeed() { state.withLock { $0.failure = nil } }

    var killed: [String] { state.withLock { $0.killed } }

    func kill(serial: String) async throws {
        try state.withLock {
            $0.killed.append(serial)
            if let failure = $0.failure { throw KillFailed(description: failure) }
        }
    }
}
