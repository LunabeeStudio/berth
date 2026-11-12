import Foundation
import Synchronization
import Testing

@testable import BerthBar
@testable import BerthCore

@Suite
struct PlainEmulatorLauncherTests {
    private struct Spawned: Equatable {
        let executable: String
        let arguments: [String]
        let log: URL
    }

    @Test
    func `launches the sdk emulator with only the avd argument and its own log`() throws {
        let spawned: Mutex<[Spawned]> = .init([])
        let launcher: SystemPlainEmulatorLauncher = .init(
            emulatorPath: { "/sdk/emulator/emulator" },
            spawn: { executable, arguments, log in spawned.withLock { $0.append(Spawned(executable: executable, arguments: arguments, log: log)) } }
        )

        try launcher.launch(avd: "Pixel_Fresh")

        let call: Spawned = try #require(spawned.withLock { $0.first })
        #expect(call.executable == "/sdk/emulator/emulator")
        #expect(call.arguments == ["-avd", "Pixel_Fresh"])
        #expect(call.log == Paths.logs.appending(path: "emulator-Pixel_Fresh.log"))
    }
}
