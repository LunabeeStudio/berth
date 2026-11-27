import Synchronization

@testable import BerthBar

final class FakeScrcpyServerLauncher: ScrcpyServerLauncher {
    struct Refused: Error {}

    private let refuses: Bool
    private let launched: Mutex<[[String]]> = .init([])
    let server: FakeScrcpyServer

    var launches: [[String]] { launched.withLock { $0 } }

    init(server: FakeScrcpyServer = .init(), refuses: Bool = false) {
        self.server = server
        self.refuses = refuses
    }

    func launch(adbArguments: [String]) throws -> any ScrcpyServer {
        if refuses { throw Refused() }
        launched.withLock { $0.append(adbArguments) }
        return server
    }
}
