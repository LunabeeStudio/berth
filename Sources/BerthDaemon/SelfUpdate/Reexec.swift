import BerthCore
import Foundation

enum Reexec {
    /// A non-executable, truncated or half-copied binary fails this check; exec into it would kill the daemon.
    static func isLoadable(path: String) async -> Bool {
        guard FileManager.default.isExecutableFile(atPath: path) else { return false }
        let result: ShellResult? = try? await Shell.run("/usr/bin/codesign", ["--verify", path], timeout: .seconds(20))
        return result?.succeeded ?? false
    }

    /// Replaces the process image, keeping the pid. Every descriptor above stderr is closed on exec so the new image can take the lock and the socket.
    /// Returns only when `execv` failed.
    static func run(path: String, arguments: [String]) {
        let open: [String] = (try? FileManager.default.contentsOfDirectory(atPath: "/dev/fd")) ?? []
        for fd in open.compactMap({ Int32($0) }) where fd > 2 {
            let flags: Int32 = fcntl(fd, F_GETFD)
            if flags >= 0 { _ = fcntl(fd, F_SETFD, flags | FD_CLOEXEC) }
        }
        let argv: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) } + [nil]
        execv(path, argv)
        Log.info("re-exec failed: \(String(cString: strerror(errno)))")
        argv.forEach { free($0) }
    }
}
