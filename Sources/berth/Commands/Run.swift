import ArgumentParser
import BerthCore
import Foundation

struct Run: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Claim an emulator, run a command with ANDROID_SERIAL set, then release it.",
        discussion: "Example: berth run --label login-tests -- ./gradlew connectedDebugAndroidTest"
    )

    @OptionGroup var options: ClaimOptions

    @Option(help: "Seconds to wait for an emulator, 0 = forever.")
    var timeout: Int = 0

    @Argument(parsing: .postTerminator, help: "Command to run, after `--`.")
    var command: [String] = []

    func validate() throws {
        if command.isEmpty { throw ValidationError("missing command: berth run [options] -- <command> [args…]") }
    }

    func run() async throws {
        let owner = ProcessInspector.owner(pid: getpid()) ?? ProcessInspector.detectOwner()
        var grant: Grant?
        try await runClient {
            grant = try await ClaimFlow.claim(options, owner: owner, timeout: timeout)
        }
        guard let grant else { throw ExitCode.failure }
        printError("berth: running on \(grant.serial)")

        let status = await execute(command, serial: grant.serial)
        _ = try? await DaemonClient.call(.release(target: grant.leaseID), autoSpawn: false)
        throw ExitCode(status)
    }

    private func execute(_ command: [String], serial: String) async -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        var environment = ProcessInfo.processInfo.environment
        environment["ANDROID_SERIAL"] = serial
        process.environment = environment

        let (exits, continuation) = AsyncStream.makeStream(of: Int32.self)
        process.terminationHandler = { process in
            continuation.yield(process.terminationStatus)
            continuation.finish()
        }
        do {
            try process.run()
        } catch {
            printError("berth: cannot run \(command.joined(separator: " ")): \(error)")
            return 127
        }

        let childPID = process.processIdentifier
        let forwarders = [SIGINT, SIGTERM, SIGHUP].map { signalNumber in
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber)
            source.setEventHandler { kill(childPID, signalNumber) }
            source.resume()
            return source
        }
        defer { forwarders.forEach { $0.cancel() } }

        var status: Int32 = 1
        for await code in exits { status = code }
        return status
    }
}
