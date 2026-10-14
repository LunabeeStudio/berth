import ArgumentParser
import BerthCore
import Foundation

struct Claim: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Lease an emulator or simulator; prints its serial or UDID (use with `adb -s`, ANDROID_SERIAL or `simctl`).",
        discussion: "Waits in a FIFO queue when none is free. Exit code 2 when --timeout elapses."
    )

    @OptionGroup var options: ClaimOptions

    @Option(help: "Seconds to wait for a device, 0 = forever.")
    var timeout: Int = 600

    @Option(help: "PID whose death releases the lease (default: nearest non-shell ancestor, e.g. the agent).")
    var ownerPid: Int32?

    @Flag(help: "Print the full grant as JSON.")
    var json = false

    func run() async throws {
        let owner = try ownerPid.map { pid in
            guard let owner = ProcessInspector.owner(pid: pid) else { throw ValidationError("no process with PID \(pid)") }
            return owner
        } ?? ProcessInspector.detectOwner()
        try await runClient {
            let grant = try await ClaimFlow.claim(options, owner: owner, timeout: timeout)
            print(json ? Wire.json(grant) : grant.serial)
        }
    }
}

struct Release: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Give a device back; it is reset to a clean state.")

    @Argument(help: "Serial (emulator-5554 or simulator UDID) or lease id.")
    var target: String

    func run() async throws {
        try await runClient {
            if case let .ok(message) = try await DaemonClient.call(.release(target: target), autoSpawn: false) {
                printError("berth: \(message)")
            }
        }
    }
}

struct Renew: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Extend a lease.")

    @Argument(help: "Serial (emulator-5554 or simulator UDID) or lease id.")
    var target: String

    @Option(help: "New lease duration in seconds from now (default from config).")
    var ttl: Int?

    func run() async throws {
        try await runClient {
            if case let .ok(message) = try await DaemonClient.call(.renew(target: target, ttl: ttl), autoSpawn: false) {
                printError("berth: \(message)")
            }
        }
    }
}

struct StopAll: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop-all",
        abstract: "Shut down every emulator berth started (leases are revoked, waiting claims fail)."
    )

    func run() async throws {
        try await runClient {
            if case let .ok(message) = try await DaemonClient.call(.stopAll, autoSpawn: false) {
                printError("berth: \(message)")
            }
        }
    }
}
