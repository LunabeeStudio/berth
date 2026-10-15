import ArgumentParser
import Foundation

struct Guard: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check a Claude Code PreToolUse Bash call for device commands outside a berth lease (hook use).",
        discussion: "Reads the hook payload on stdin. Exit 0 allows the call; exit 2 blocks it with the reason on stderr."
    )

    func run() throws {
        let input: Data = FileHandle.standardInput.readDataToEndOfFile()
        guard
            let command = HookPayload.command(from: input),
            case let .deny(reason) = DeviceCommandGuard(environment: ProcessInfo.processInfo.environment).verdict(for: command)
        else { return }
        printError(reason)
        throw ExitCode(2)
    }
}
