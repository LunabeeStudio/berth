import BerthCore
import Foundation

struct AdbEmulatorKiller: EmulatorKiller {
    private struct KillFailed: Error, CustomStringConvertible {
        let description: String
    }

    private let adb: String

    init(adb: String = Config.defaultADBPath()) {
        self.adb = adb
    }

    func kill(serial: String) async throws {
        let result: ShellResult = try await Shell.run(adb, ["-s", serial, "emu", "kill"], timeout: .seconds(15))
        guard result.succeeded else {
            let detail: String = result.timedOut ? "timed out" : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw KillFailed(description: "kill \(serial) failed: \(detail)")
        }
    }
}
