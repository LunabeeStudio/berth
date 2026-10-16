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
        let android = AndroidBackend(config: config)
        let simulators = IOSSimulatorBackend(config: config)
        let backend = DeviceRouter(config: config, android: android, ios: simulators)
        Log.info("daemon \(getpid()) starting v\(BerthVersion.current): sdk=\(config.resolvedSDKRoot) pool=\(config.pool.map { "\($0.name)x\($0.maxInstances)" }.joined(separator: ",")) maxRunning=\(config.maxRunning)")
        if !config.entries(for: .android).isEmpty {
            _ = try? await Shell.run(android.adb, ["start-server"], timeout: .seconds(30))
        }
        await simulators.provision()

        let broker = Broker(config: config, backend: backend, store: StateStore(url: Paths.state))
        await broker.restore()

        let executable = LaunchAgent.currentExecutablePath()
        let watch = ExecutableWatch(path: executable)
        Task {
            while true {
                try? await Task.sleep(for: reapInterval)
                await broker.reap()
                if watch.hasChanged(), await broker.isIdle {
                    Log.info("re-exec after binary change")
                    Reexec.run(path: executable, arguments: CommandLine.arguments)
                }
            }
        }

        let autoUpdater = AutoUpdater(source: Updater(executablePath: executable), autoUpdate: config.autoUpdate)
        Task { await autoUpdater.run() }

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
        let fd = open(Paths.lock.path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw DaemonError.lock(String(cString: strerror(errno))) }
        return flock(fd, LOCK_EX | LOCK_NB) == 0
    }
}
