import BerthCore
import Foundation

struct AdbEmulatorKiller: EmulatorKiller {
    private let adb: String

    init(adb: String = Config.defaultADBPath()) {
        self.adb = adb
    }

    func kill(serial: String) async throws {
        let result: ShellResult = try await Shell.run(adb, ["-s", serial, "emu", "kill"], timeout: .seconds(15))
        if result.timedOut { throw EmulatorKillError.timedOut(serial: serial) }
        guard result.succeeded else {
            throw EmulatorKillError.failed(serial: serial, stderr: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
