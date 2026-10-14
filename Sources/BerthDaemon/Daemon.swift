import BerthCore
import Foundation

public enum DaemonError: Error, CustomStringConvertible {
    case lock(String)

    public var description: String {
        switch self {
        case let .lock(reason): "cannot lock \(Paths.lock.path): \(reason)"
        }
    }
}

public enum Daemon {
    static let reapInterval: Duration = .seconds(5)

    public static func run() async throws {
        try Paths.ensureDirectories()
        guard try acquireLock() else {
            Log.info("another berth daemon is already running")
            return
        }
        signal(SIGHUP, SIG_IGN)
        signal(SIGPIPE, SIG_IGN)

        let config = try await Config.loadOrCreate(discoverModels: AndroidBackend.listAVDs)
        let backend = AndroidBackend(config: config)
        Log.info("daemon \(getpid()) starting: sdk=\(config.resolvedSDKRoot) pool=\(config.pool.map { "\($0.avd)x\($0.maxInstances)" }.joined(separator: ",")) maxRunning=\(config.maxRunning)")
        _ = try? await Shell.run(backend.adb, ["start-server"], timeout: .seconds(30))

        let broker = Broker(config: config, backend: backend, store: StateStore(url: Paths.state))
        await broker.restore()

        Task {
            while true {
                try? await Task.sleep(for: reapInterval)
                await broker.reap()
            }
        }

        let server = Server(broker: broker) {
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                Log.info("daemon stopping on request")
                try? FileManager.default.removeItem(at: Paths.socket)
                exit(0)
            }
        }
        try await server.run(socketPath: Paths.socket.path)
    }

    private static func acquireLock() throws -> Bool {
        let fd = open(Paths.lock.path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw DaemonError.lock(String(cString: strerror(errno))) }
        return flock(fd, LOCK_EX | LOCK_NB) == 0
    }
}
