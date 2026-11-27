import Synchronization

@testable import BerthBar
@testable import BerthCore

final class FakeCommandRunner: CommandRunner {
    typealias Handler = @Sendable (_ executable: String, _ arguments: [String]) -> ShellResult

    private let handler: Handler
    private let recorded: Mutex<[[String]]> = .init([])

    var calls: [[String]] { recorded.withLock { $0 } }

    init(_ handler: @escaping Handler) {
        self.handler = handler
    }

    func run(_ executable: String, _ arguments: [String], timeout: Duration) async throws -> ShellResult {
        recorded.withLock { $0.append(arguments) }
        return handler(executable, arguments)
    }

    static func ok(_ stdout: String = "") -> ShellResult {
        .init(status: 0, stdout: stdout, stderr: "", timedOut: false)
    }

    static func failure(_ stderr: String) -> ShellResult {
        .init(status: 1, stdout: "", stderr: stderr, timedOut: false)
    }

    static func hung() -> ShellResult {
        .init(status: 15, stdout: "", stderr: "", timedOut: true)
    }
}
