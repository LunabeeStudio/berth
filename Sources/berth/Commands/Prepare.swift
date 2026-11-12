import ArgumentParser
import BerthCore

struct Prepare: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create the clean snapshot an AVD is reset to after each lease (one-time per AVD).",
        discussion: "The daemon cold boots the AVD headless, disables animations, saves the snapshot and shuts down. The AVD joins the pool on success. Ctrl-C cancels."
    )

    @Argument(help: "AVD name, as listed by `emulator -list-avds`.")
    var avd: String

    @Option(help: "Seconds to let the system settle after boot before saving.")
    var settle: Int = 20

    func run() async throws {
        try await runClient {
            let message: String = try await DaemonClient.prepare(.init(avd: avd, settle: settle)) { printError("berth: \($0)") }
            printError("berth: \(message)")
        }
    }
}
