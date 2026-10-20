import BerthCore
import Synchronization

@testable import BerthBar

final class StubActions: DaemonActions {
    private struct StubError: Error, CustomStringConvertible {
        let description: String
    }

    private let state: Mutex<State>

    private struct State {
        var failure: String?
        var releases: [String] = []
    }

    init(failure: String?) {
        state = .init(State(failure: failure))
    }

    var failure: String? {
        get { state.withLock { $0.failure } }
        set { state.withLock { $0.failure = newValue } }
    }

    var releases: [String] { state.withLock { $0.releases } }

    func claim(_ request: ClaimRequest) async throws {
        if let failure { throw StubError(description: failure) }
    }

    func release(serial: String) async throws {
        state.withLock { $0.releases.append(serial) }
        if let failure { throw StubError(description: failure) }
    }
}
