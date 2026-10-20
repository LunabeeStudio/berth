import Foundation
import Testing

@testable import BerthBar

@MainActor
@Suite
struct SystemMirrorLauncherTests {
    @Test
    func `runs the executable with ADB set, logs its output and reports the exit code`() async throws {
        let log: URL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "mirror-emulator-5554.log")
        let launcher: SystemMirrorLauncher = .init(adb: "/sdk/platform-tools/adb")

        let code: Int32 = try await withCheckedThrowingContinuation { continuation in
            do {
                _ = try launcher.launch(executable: "/bin/sh", arguments: ["-c", "echo $ADB; exit 3"], log: log) { continuation.resume(returning: $0) }
            } catch {
                continuation.resume(throwing: error)
            }
        }

        #expect(code == 3)
        #expect(try String(contentsOf: log, encoding: .utf8) == "/sdk/platform-tools/adb\n")
    }

    @Test
    func `a missing executable throws`() {
        let log: URL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).log")
        let launcher: SystemMirrorLauncher = .init(adb: "adb")

        #expect(throws: (any Error).self) {
            try launcher.launch(executable: "/nonexistent/scrcpy", arguments: [], log: log) { _ in }
        }
    }
}
