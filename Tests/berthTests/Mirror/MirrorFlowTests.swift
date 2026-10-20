import BerthCore
import Foundation
import Testing

@testable import berth

@MainActor
@Suite
struct MirrorFlowTests {
    private struct Boom: Error, CustomStringConvertible {
        let description: String = "boom"
    }

    private static func makeScrcpyDirectory() throws -> URL {
        let directory: URL = FileManager.default.temporaryDirectory.appending(path: "flow-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scrcpy: URL = directory.appending(path: "scrcpy")
        FileManager.default.createFile(atPath: scrcpy.path, contents: Data("#!/bin/sh\n".utf8), attributes: [.posixPermissions: 0o755])
        return directory
    }

    @Test
    func `android launches scrcpy with control, the serial, the title and ADB`() async throws {
        let directory: URL = try Self.makeScrcpyDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let launcher: FakeAndroidMirrorLauncher = .init()

        try await makeFlow(scrcpyDirectory: directory, launcher: launcher).open(.android(serial: "emulator-5554", model: "Pixel_9"))

        let launch: FakeAndroidMirrorLauncher.Launch = try #require(launcher.launches.first)
        #expect(launch.executable == directory.appending(path: "scrcpy").path)
        #expect(launch.arguments.starts(with: ["-s", "emulator-5554", "--no-audio", "--window-title", "emulator-5554 Pixel_9"]))
        #expect(!launch.arguments.contains("--no-control"))
        #expect(launch.environment["ADB"] == "/sdk/platform-tools/adb")
        #expect(launch.log.path == "/tmp/berth-logs/mirror-emulator-5554.log")
    }

    @Test
    func `android without scrcpy reports it missing`() async {
        let launcher: FakeAndroidMirrorLauncher = .init()

        await #expect(throws: MirrorError.scrcpyNotFound) {
            try await makeFlow(scrcpyDirectory: nil, launcher: launcher).open(.android(serial: "emulator-5554", model: "Pixel_9"))
        }
        #expect(launcher.launches.isEmpty)
    }

    @Test
    func `android spawn failure is reported with the serial`() async throws {
        let directory: URL = try Self.makeScrcpyDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let launcher: FakeAndroidMirrorLauncher = .init()
        launcher.failure = Boom()

        await #expect(throws: MirrorError.failed(serial: "emulator-5554", reason: "boom")) {
            try await makeFlow(scrcpyDirectory: directory, launcher: launcher).open(.android(serial: "emulator-5554", model: "Pixel_9"))
        }
    }

    @Test
    func `ios opens the DeviceHub url`() async throws {
        let opener: FakeSimulatorMirrorOpener = .init()

        try await makeFlow(scrcpyDirectory: nil, opener: opener).open(.ios(udid: "UDID-1"))

        #expect(opener.opened.map(\.absoluteString) == ["devices://device/open?id=UDID-1"])
    }

    @Test
    func `ios without DeviceHub reports it missing`() async {
        let opener: FakeSimulatorMirrorOpener = .init()
        opener.handlesScheme = false

        await #expect(throws: MirrorError.deviceHubNotFound) {
            try await makeFlow(scrcpyDirectory: nil, opener: opener).open(.ios(udid: "UDID-1"))
        }
    }

    @Test
    func `ios open failure is reported with the udid`() async {
        let opener: FakeSimulatorMirrorOpener = .init()
        opener.failure = Boom()

        await #expect(throws: MirrorError.failed(serial: "UDID-1", reason: "boom")) {
            try await makeFlow(scrcpyDirectory: nil, opener: opener).open(.ios(udid: "UDID-1"))
        }
    }

    private func makeFlow(
        scrcpyDirectory: URL?,
        launcher: FakeAndroidMirrorLauncher = .init(),
        opener: FakeSimulatorMirrorOpener = .init()
    ) -> MirrorFlow {
        .init(
            locator: .init(environment: ["PATH": scrcpyDirectory?.path ?? ""], fallbackDirectories: []),
            launcher: launcher,
            opener: opener,
            adb: "/sdk/platform-tools/adb",
            logs: URL(fileURLWithPath: "/tmp/berth-logs")
        )
    }
}
