import ArgumentParser
import BerthCore
import Foundation

struct Update: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Update berth to the latest GitHub release.")

    @Flag(help: "Only report the running and the latest version.")
    var check: Bool = false

    func run() async throws {
        let updater: Updater = .init()
        do {
            let result: UpdateCheck = try await updater.check()
            switch result {
            case let .upToDate(current, latest):
                print(check ? "berth: running \(current), latest \(latest)" : "berth: up to date (\(current))")
            case let .available(current, latest, release):
                if check {
                    print("berth: running \(current), latest \(latest)")
                } else {
                    try await updater.install(release)
                    print("berth: updated \(current) → \(latest)")
                }
            }
        } catch {
            printError("berth: \(error.localizedDescription)")
            throw ExitCode(1)
        }
    }
}
