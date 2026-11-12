import ArgumentParser
import BerthCore
import Foundation

struct BarCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bar",
        abstract: "Manage berth-bar, the menu bar app.",
        subcommands: [BarInstall.self, BarUninstall.self]
    )
}

struct BarInstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install", abstract: "Start berth-bar now and at login via launchd.")

    func run() async throws {
        let berth: String = LaunchAgent.currentExecutablePath()
        let bar: String = URL(fileURLWithPath: berth).deletingLastPathComponent().appending(path: "berth-bar").path
        guard FileManager.default.isExecutableFile(atPath: bar) else {
            printError("berth: berth-bar not found next to \(berth)")
            throw ExitCode.failure
        }
        let agent: LaunchAgent = .bar
        try agent.writeBar(executable: bar, environment: ProcessInfo.processInfo.environment)
        await agent.bootout()
        let survivors: [Int32] = await ExecutableReplacer().stop(executable: bar)
        guard survivors.isEmpty else {
            printError("berth: berth-bar still running after SIGTERM (pid \(survivors.map(String.init).joined(separator: ", "))); nothing started")
            throw ExitCode.failure
        }
        try await agent.bootstrap()
        printError("berth: installed \(agent.plist.path)")
    }
}

struct BarUninstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "uninstall", abstract: "Stop berth-bar and remove its launchd agent.")

    func run() async throws {
        let agent: LaunchAgent = .bar
        await agent.bootout()
        try? agent.remove()
        printError("berth: uninstalled")
    }
}
