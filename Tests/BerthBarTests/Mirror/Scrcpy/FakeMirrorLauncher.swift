import Foundation

@testable import BerthBar

@MainActor
final class FakeMirrorLauncher: MirrorLauncher {
    private(set) var launches: [Launch] = []
    var failure: Bool = false

    func launch(
        executable: String,
        arguments: [String],
        log: URL,
        onExit: @escaping @MainActor @Sendable (Int32) -> Void
    ) throws -> any MirrorProcess {
        if failure { throw CocoaError(.fileNoSuchFile) }
        let process: FakeProcess = .init(pid: Int32(100 + launches.count))
        launches.append(.init(executable: executable, arguments: arguments, log: log, process: process, onExit: onExit))
        return process
    }
}

extension FakeMirrorLauncher {
    final class FakeProcess: MirrorProcess {
        let pid: Int32
        private(set) var terminated: Bool = false

        init(pid: Int32) {
            self.pid = pid
        }

        func terminate() {
            terminated = true
        }
    }

    struct Launch {
        let executable: String
        let arguments: [String]
        let log: URL
        let process: FakeProcess
        let onExit: @MainActor @Sendable (Int32) -> Void
    }
}
