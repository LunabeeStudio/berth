import BerthCore
import Foundation

struct ScrcpyDeviceClipboard: DeviceClipboard {
    private static let minimumCleanupCommandTimeout: Duration = .milliseconds(500)

    private let adb: String
    private let scrcpy: ScrcpyLocator
    private let serverLocator: ScrcpyServerLocator
    private let runner: any CommandRunner
    private let launcher: any ScrcpyServerLauncher
    private let connect: @Sendable (UInt16) -> (any ScrcpyControlChannel)?
    private let scid: @Sendable () -> Int
    private let timeout: Duration
    private let cleanupTimeout: Duration

    /// `timeout` bounds the read and `cleanupTimeout` the cleanup after it: together they are the 15 s a click may take.
    init(
        adb: String = Config.defaultADBPath(),
        scrcpy: ScrcpyLocator = .init(),
        serverLocator: ScrcpyServerLocator = .init(),
        runner: any CommandRunner = SystemCommandRunner(),
        launcher: (any ScrcpyServerLauncher)? = nil,
        connect: @escaping @Sendable (UInt16) -> (any ScrcpyControlChannel)? = { ScrcpyControlSocket(loopbackPort: $0) },
        scid: @escaping @Sendable () -> Int = ScrcpyServerCommand.randomScid,
        timeout: Duration = .seconds(12),
        cleanupTimeout: Duration = .seconds(3)
    ) {
        self.adb = adb
        self.scrcpy = scrcpy
        self.serverLocator = serverLocator
        self.runner = runner
        self.launcher = launcher ?? SystemScrcpyServerLauncher(adb: adb)
        self.connect = connect
        self.scid = scid
        self.timeout = timeout
        self.cleanupTimeout = cleanupTimeout
    }

    func text(serial: String) async throws -> String? {
        guard let scrcpyPath = scrcpy.locate() else { throw DeviceClipboardError.scrcpyNotFound }
        guard let serverPath = serverLocator.locate(scrcpyPath: scrcpyPath) else { throw DeviceClipboardError.serverNotFound }
        let deadline: ContinuousClock.Instant = .now + timeout
        let command: ScrcpyServerCommand = .init(version: try await version(of: scrcpyPath, serial: serial, deadline: deadline), scid: scid())
        try await adbRun(["-s", serial, "push", serverPath, ScrcpyServerCommand.jarPath], serial: serial, deadline: deadline)
        var port: UInt16?
        var server: (any ScrcpyServer)?
        do {
            let forwarded: UInt16 = try await forward(command, serial: serial, deadline: deadline)
            port = forwarded
            let started: any ScrcpyServer = try launcher.launch(adbArguments: command.adbArguments(serial: serial))
            server = started
            let text: String? = try await readOnQueue(serial: serial, port: forwarded, deadline: deadline, server: started)
            await cleanUp(server: started, command: command, port: port, serial: serial)
            return text?.isEmpty == false ? text : nil
        } catch {
            await cleanUp(server: server, command: command, port: port, serial: serial)
            throw error
        }
    }

    private func readOnQueue(
        serial: String,
        port: UInt16,
        deadline: ContinuousClock.Instant,
        server: any ScrcpyServer
    ) async throws -> String? {
        let connect: @Sendable (UInt16) -> (any ScrcpyControlChannel)? = connect
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(
                    with: Result {
                        try ScrcpyClipboardExchange.read(
                            serial: serial,
                            deadline: deadline,
                            connect: { connect(port) },
                            serverFailure: server.failureLine
                        )
                    }
                )
            }
        }
    }

    private func version(of scrcpyPath: String, serial: String, deadline: ContinuousClock.Instant) async throws -> String {
        let result: ShellResult = try await execute(scrcpyPath, ["--version"], serial: serial, deadline: deadline)
        guard let version = ScrcpyVersion.parse(versionOutput: result.stdout) else {
            throw DeviceClipboardError.failed(line: "cannot read the scrcpy version")
        }
        return version
    }

    private func forward(_ command: ScrcpyServerCommand, serial: String, deadline: ContinuousClock.Instant) async throws -> UInt16 {
        let output: String = try await adbRun(["-s", serial, "forward", "tcp:0", command.socketName], serial: serial, deadline: deadline)
        guard let port = UInt16(output) else { throw DeviceClipboardError.failed(line: "adb forward printed \"\(output)\" instead of a port") }
        return port
    }

    @discardableResult
    private func adbRun(_ arguments: [String], serial: String, deadline: ContinuousClock.Instant) async throws -> String {
        let result: ShellResult = try await execute(adb, arguments, serial: serial, deadline: deadline)
        guard result.succeeded, !AdbOutput.reportsError(stdout: result.stdout, stderr: result.stderr) else {
            throw DeviceClipboardError.failed(line: AdbOutput.errorLine(stdout: result.stdout, stderr: result.stderr, status: result.status))
        }
        return result.trimmedOutput
    }

    private func execute(_ executable: String, _ arguments: [String], serial: String, deadline: ContinuousClock.Instant) async throws -> ShellResult {
        let remaining: Duration = ContinuousClock.now.duration(to: deadline)
        guard remaining > .zero else { throw DeviceClipboardError.timedOut(serial: serial) }
        let result: ShellResult = try await runner.run(executable, arguments, timeout: remaining)
        if result.timedOut { throw DeviceClipboardError.timedOut(serial: serial) }
        return result
    }

    private func cleanUp(server: (any ScrcpyServer)?, command: ScrcpyServerCommand, port: UInt16?, serial: String) async {
        let deadline: ContinuousClock.Instant = .now + cleanupTimeout
        let exitedOnItsOwn: Bool = await server?.stop() ?? true
        async let killing: Void = killServer(of: command, serial: serial, deadline: deadline, unless: exitedOnItsOwn)
        async let unforwarding: Void = removeForwards(of: command, port: port, serial: serial, deadline: deadline)
        _ = await (killing, unforwarding)
    }

    private func killServer(of command: ScrcpyServerCommand, serial: String, deadline: ContinuousClock.Instant, unless exitedOnItsOwn: Bool) async {
        guard !exitedOnItsOwn else { return }
        await bestEffort(command.killArguments(serial: serial), deadline: deadline)
    }

    /// A forward whose creation timed out may exist without its port being known: it is found by its socket name.
    private func removeForwards(of command: ScrcpyServerCommand, port: UInt16?, serial: String, deadline: ContinuousClock.Instant) async {
        let endpoints: [String] =
            if let port {
                ["tcp:\(port)"]
            } else {
                await command.forwardEndpoints(in: bestEffort(["forward", "--list"], deadline: deadline)?.stdout ?? "", serial: serial)
            }
        for endpoint in endpoints {
            await bestEffort(["-s", serial, "forward", "--remove", endpoint], deadline: deadline)
        }
    }

    @discardableResult
    private func bestEffort(_ arguments: [String], deadline: ContinuousClock.Instant) async -> ShellResult? {
        let remaining: Duration = max(Self.minimumCleanupCommandTimeout, ContinuousClock.now.duration(to: deadline))
        return try? await runner.run(adb, arguments, timeout: remaining)
    }
}
