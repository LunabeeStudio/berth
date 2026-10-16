import ArgumentParser
import BerthCore
import BerthDaemon
import Foundation

struct DaemonCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "daemon",
        abstract: "Manage the background broker (auto-started by any client command).",
        subcommands: [DaemonRun.self, DaemonStop.self, DaemonInstall.self, DaemonUninstall.self],
        defaultSubcommand: DaemonRun.self
    )
}

struct DaemonRun: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "run", abstract: "Run the broker in the foreground.")

    func run() async throws {
        try await Daemon.run()
    }
}

struct DaemonStop: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop the broker (emulators keep running and are adopted on next start). Use after editing the config."
    )

    func run() async throws {
        do {
            if case let .ok(message) = try await DaemonClient.call(.shutdown, autoSpawn: false) {
                printError("berth: \(message)")
            }
        } catch ClientError.daemonUnavailable {
            printError("berth: daemon is not running")
        }
    }
}

struct DaemonInstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install", abstract: "Start the broker at login via launchd.")

    func run() async throws {
        let executable: String = LaunchAgent.currentExecutablePath()
        try Paths.ensureDirectories()
        let agent: LaunchAgent = .daemon
        let plist: [String: Any] = [
            "Label": agent.label,
            "ProgramArguments": [executable, "daemon", "run"],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "StandardOutPath": Paths.daemonLog.path,
            "StandardErrorPath": Paths.daemonLog.path,
        ]
        try agent.write(plist)
        _ = try? await DaemonClient.call(.shutdown, autoSpawn: false)
        _ = try? await Shell.run("/bin/launchctl", ["bootout", agent.domain, agent.plist.path])
        let result = try await Shell.run("/bin/launchctl", ["bootstrap", agent.domain, agent.plist.path])
        guard result.succeeded else {
            printError("berth: launchctl bootstrap failed: \(result.stderr)")
            throw ExitCode.failure
        }
        printError("berth: installed \(agent.plist.path)")
    }
}

struct DaemonUninstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "uninstall", abstract: "Remove the launchd agent.")

    func run() async throws {
        let agent: LaunchAgent = .daemon
        _ = try? await Shell.run("/bin/launchctl", ["bootout", agent.domain, agent.plist.path])
        try? agent.remove()
        printError("berth: uninstalled")
    }
}
