import ArgumentParser
import BerthCore

struct MirrorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mirror",
        abstract: "Open a window on a leased device so a human can act on it (login, 2FA, captcha).",
        discussion: "Returns as soon as the window is open. Android needs scrcpy; iOS needs Xcode 27 (DeviceHub)."
    )

    @Argument(help: "Serial (emulator-5554) or simulator UDID of a leased device.")
    var serial: String

    @MainActor
    private static func open(_ target: MirrorTarget) async throws {
        try await MirrorFlow().open(target)
    }

    func run() async throws {
        try await runClient {
            let snapshot: StateSnapshot = try await DaemonClient.snapshot(autoSpawn: false)
            do {
                let target: MirrorTarget = try MirrorResolver.resolve(serial: serial, in: snapshot)
                try await Self.open(target)
            } catch let error as MirrorError {
                printError("berth: \(error)")
                throw ExitCode.failure
            }
            printError("berth: mirror open for \(serial), close the window when done")
        }
    }
}
