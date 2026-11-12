import ArgumentParser
import BerthCore

extension LaunchAgent {
    static let daemon: LaunchAgent = .init(label: "com.berth.daemon")

    func bootout() async {
        _ = try? await Shell.run("/bin/launchctl", ["bootout", domain, plist.path])
    }

    func bootstrap() async throws {
        let result: ShellResult = try await Shell.run("/bin/launchctl", ["bootstrap", domain, plist.path])
        guard result.succeeded else {
            printError("berth: launchctl bootstrap failed: \(result.stderr)")
            throw ExitCode.failure
        }
    }
}
