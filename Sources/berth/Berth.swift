import ArgumentParser
import BerthCore
import Foundation

@main
struct Berth: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "berth",
        abstract: "Lease Android emulators and iOS simulators to parallel AI agents without collisions.",
        version: BerthVersion.current,
        subcommands: [
            Claim.self, Release.self, Renew.self, Run.self,
            Status.self, Top.self, Prepare.self, StopAll.self, DaemonCommand.self, Guard.self, Update.self, Mirror.self,
        ]
    )
}

struct ClaimOptions: ParsableArguments {
    @Option(help: "Only accept this AVD (default: any Android emulator in the pool).")
    var avd: String?

    @Flag(help: "Claim an iOS simulator instead of an Android emulator.")
    var ios = false

    @Option(help: "Only accept this simulator pool entry, e.g. \"iPhone 17\" (implies --ios).")
    var simulator: String?

    @Option(help: "Lease duration in seconds before it is reclaimed (default from config).")
    var ttl: Int?

    @Option(help: "Free text shown in `berth top`, e.g. the task name.")
    var label: String?

    var platform: Platform? { ios || simulator != nil ? .ios : nil }
    var resolvedPlatform: Platform { platform ?? .android }

    func validate() throws {
        if avd != nil && platform == .ios { throw ValidationError("--avd cannot be combined with --ios or --simulator") }
    }
}

enum ClaimFlow {
    static func claim(_ options: ClaimOptions, owner: Owner, timeout: Int) async throws -> Grant {
        let request: ClaimRequest = .init(model: options.simulator ?? options.avd, platform: options.platform, ttl: options.ttl, label: options.label, owner: owner)
        return try await DaemonClient.claim(request, timeout: timeout > 0 ? .seconds(timeout) : nil) { position in
            printError("berth: waiting for a device (queue position \(position))")
        }
    }
}

func printError(_ message: String) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
}

/// Maps client errors to exit codes: 2 = timed out waiting, 1 = anything else.
func runClient(_ body: () async throws -> Void) async throws {
    do {
        try await body()
    } catch ClientError.timedOut {
        printError("berth: \(ClientError.timedOut)")
        throw ExitCode(2)
    } catch let error as ClientError {
        printError("berth: \(error)")
        throw ExitCode.failure
    }
}

