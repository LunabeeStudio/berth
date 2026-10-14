import ArgumentParser
import BerthCore
import Foundation

struct Status: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show emulators, leases and the waiting queue.")

    @Flag(help: "Print the raw state as JSON.")
    var json = false

    func run() async throws {
        try await runClient {
            let snapshot = try await DaemonClient.snapshot()
            if json {
                print(Wire.json(snapshot))
            } else {
                let lines = StatusRenderer(snapshot: snapshot, now: Date(), colors: isatty(1) == 1).lines(selected: nil)
                print(lines.joined(separator: "\n"))
            }
        }
    }
}
