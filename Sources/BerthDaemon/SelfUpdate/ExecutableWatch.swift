import Foundation

/// Detects that the daemon's own executable file was replaced on disk.
struct ExecutableWatch: Sendable {
    let path: String
    private let initial: Identity?
    private var pending: Identity?

    init(path: String) {
        self.path = path
        initial = Self.identity(of: path)
    }

    /// True once the file differs from the one at start and was identical on two consecutive polls,
    /// so a copy still being written is not executed. A vanished or unreadable file counts as unchanged.
    mutating func hasSettledChange() -> Bool {
        guard let initial, let current = Self.identity(of: path), current != initial else {
            pending = nil
            return false
        }
        defer { pending = current }
        return pending == current
    }

    private static func identity(of path: String) -> Identity? {
        var info: stat = .init()
        guard stat(path, &info) == 0 else { return nil }
        return .init(
            inode: UInt64(info.st_ino),
            size: Int64(info.st_size),
            modifiedSeconds: info.st_mtimespec.tv_sec,
            modifiedNanoseconds: info.st_mtimespec.tv_nsec
        )
    }
}

private extension ExecutableWatch {
    struct Identity: Equatable, Sendable {
        let inode: UInt64
        let size: Int64
        let modifiedSeconds: Int
        let modifiedNanoseconds: Int
    }
}
