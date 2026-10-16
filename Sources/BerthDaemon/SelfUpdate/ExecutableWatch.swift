import Foundation

/// Detects that the daemon's own executable file was replaced on disk.
struct ExecutableWatch: Sendable {
    private struct Identity: Equatable, Sendable {
        let inode: UInt64
        let size: Int64
        let modified: timespec

        static func == (lhs: Identity, rhs: Identity) -> Bool {
            lhs.inode == rhs.inode && lhs.size == rhs.size
                && lhs.modified.tv_sec == rhs.modified.tv_sec && lhs.modified.tv_nsec == rhs.modified.tv_nsec
        }
    }

    let path: String
    private let initial: Identity?

    init(path: String) {
        self.path = path
        initial = Self.identity(of: path)
    }

    /// A vanished or unreadable file counts as unchanged: exec into nothing would kill the daemon.
    func hasChanged() -> Bool {
        guard let initial, let current = Self.identity(of: path) else { return false }
        return current != initial
    }

    private static func identity(of path: String) -> Identity? {
        var info: stat = .init()
        guard stat(path, &info) == 0 else { return nil }
        return .init(inode: UInt64(info.st_ino), size: Int64(info.st_size), modified: info.st_mtimespec)
    }
}
