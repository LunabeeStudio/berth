import BerthCore
import Foundation

enum Reexec {
    /// Replaces the process image, keeping the pid. Every descriptor above stderr is closed on exec so the new image can take the lock and the socket.
    static func run(path: String, arguments: [String]) -> Never {
        for fd in 3..<getdtablesize() {
            let flags: Int32 = fcntl(fd, F_GETFD)
            if flags >= 0 { _ = fcntl(fd, F_SETFD, flags | FD_CLOEXEC) }
        }
        let argv: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) } + [nil]
        execv(path, argv)
        Log.info("re-exec failed: \(String(cString: strerror(errno)))")
        exit(1)
    }
}
