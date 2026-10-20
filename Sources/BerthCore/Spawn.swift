import Darwin
import Foundation

public enum SpawnError: Error, CustomStringConvertible {
    case failed(String, Int32)

    public var description: String {
        switch self {
        case let .failed(exe, code): "posix_spawn \(exe) failed: \(String(cString: strerror(code)))"
        }
    }
}

public enum Spawn {
    /// Own session so it outlives the parent and its terminal signals; only stdio is inherited.
    @discardableResult
    public static func detached(_ executable: String, _ arguments: [String], log: URL, environment: [String: String]? = nil) throws -> pid_t {
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT))

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_addopen(&actions, 1, log.path, O_WRONLY | O_CREAT | O_APPEND, 0o644)
        posix_spawn_file_actions_adddup2(&actions, 1, 2)

        var argv: [UnsafeMutablePointer<CChar>?] = ([executable] + arguments).map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }

        let resolved: [String: String] = environment ?? ProcessInfo.processInfo.environment
        var envp: [UnsafeMutablePointer<CChar>?] = resolved.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { envp.forEach { free($0) } }

        var pid: pid_t = 0
        let code: Int32 = posix_spawn(&pid, executable, &actions, &attributes, &argv, &envp)
        guard code == 0 else { throw SpawnError.failed(executable, code) }
        return pid
    }
}
