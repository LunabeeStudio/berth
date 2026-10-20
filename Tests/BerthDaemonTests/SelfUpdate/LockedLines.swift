import Synchronization

final class LockedLines: Sendable {
    private let storage: Mutex<[String]> = .init([])

    var all: [String] { storage.withLock { $0 } }

    var count: Int { storage.withLock { $0.count } }

    func add(_ line: String) { storage.withLock { $0.append(line) } }
}
