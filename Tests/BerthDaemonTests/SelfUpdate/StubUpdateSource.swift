import BerthCore
import Foundation
import Synchronization

final class StubUpdateSource: UpdateSource {
    private let state: Mutex<State>

    var installs: Int { state.withLock { $0.installs } }
    var checks: Int { state.withLock { $0.checks } }

    init(_ result: Result<UpdateCheck, any Error>) {
        state = .init(.init(result: result))
    }

    static func newer() -> StubUpdateSource {
        let release: Release = try! JSONDecoder().decode(Release.self, from: Data(#"{"tagName":"v2.0.0","assets":[]}"#.utf8))
        return .init(.success(.available(current: .init(major: 1, minor: 0, patch: 0), latest: .init(major: 2, minor: 0, patch: 0), release: release)))
    }

    func check() async throws -> UpdateCheck {
        try state.withLock {
            $0.checks += 1
            return try $0.result.get()
        }
    }

    func install(_ release: Release) async throws {
        state.withLock { $0.installs += 1 }
    }
}

private extension StubUpdateSource {
    struct State {
        var result: Result<UpdateCheck, any Error>
        var installs: Int = 0
        var checks: Int = 0
    }
}
