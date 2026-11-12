import BerthCore
import Foundation

struct SystemPlainEmulatorLauncher: PlainEmulatorLauncher {
    let emulatorPath: @Sendable () -> String
    let spawn: @Sendable (_ executable: String, _ arguments: [String], _ log: URL) throws -> Void

    init(
        emulatorPath: @escaping @Sendable () -> String = { ((try? Config.load()) ?? Config()).emulatorPath },
        spawn: @escaping @Sendable (String, [String], URL) throws -> Void = { _ = try Spawn.detached($0, $1, log: $2) }
    ) {
        self.emulatorPath = emulatorPath
        self.spawn = spawn
    }

    func launch(avd: String) throws {
        try Paths.ensureDirectories()
        try spawn(emulatorPath(), ["-avd", avd], Paths.logs.appending(path: "emulator-\(avd).log"))
    }
}
