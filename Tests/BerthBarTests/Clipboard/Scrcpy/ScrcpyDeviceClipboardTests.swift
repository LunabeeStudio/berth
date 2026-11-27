import Foundation
import Testing

@testable import BerthBar
@testable import BerthCore

@Suite
struct ScrcpyDeviceClipboardTests {
    private static let serial: String = "R3CT312YV5B"
    private static let scid: Int = 255
    private static let socket: String = "localabstract:scrcpy_000000ff"
    private static let removeForward: [String] = ["-s", serial, "forward", "--remove", "tcp:51234"]
    private static let listing: String = "\(serial) tcp:51234 \(socket)\nother tcp:1 localabstract:scrcpy_000000ff\n"

    private struct Rig {
        let clipboard: ScrcpyDeviceClipboard
        let runner: FakeCommandRunner
        let launcher: FakeScrcpyServerLauncher
        let channel: FakeControlChannel
        let scrcpyDirectory: URL

        func removeScrcpy() {
            try? FileManager.default.removeItem(at: scrcpyDirectory)
        }
    }

    private static func rig(
        script: [ScrcpyReadOutcome] = [.bytes([0]), .bytes(ScrcpyDeviceMessageTests.clipboard("hello"))],
        server: FakeScrcpyServer = .init(),
        launcherRefuses: Bool = false,
        timeout: Duration = .seconds(2),
        scrcpyDirectory: URL? = nil,
        failing: @escaping @Sendable (_ arguments: [String]) -> ShellResult? = { _ in nil }
    ) throws -> Rig {
        let directory: URL = try scrcpyDirectory ?? Self.installedScrcpy()
        let runner: FakeCommandRunner = .init { _, arguments in
            if let result = failing(arguments) { return result }
            if arguments == ["--version"] { return FakeCommandRunner.ok("scrcpy 5.0.1 <https://github.com/Genymobile/scrcpy>\n") }
            if arguments.contains("forward"), arguments.contains("--list") { return FakeCommandRunner.ok(Self.listing) }
            if arguments.contains("forward"), arguments.contains("tcp:0") { return FakeCommandRunner.ok("51234\n") }
            return FakeCommandRunner.ok()
        }
        let launcher: FakeScrcpyServerLauncher = .init(server: server, refuses: launcherRefuses)
        let channel: FakeControlChannel = .init(script)
        let clipboard: ScrcpyDeviceClipboard = .init(
            adb: "/sdk/adb",
            scrcpy: .init(environment: ["PATH": ""], fallbackDirectories: [directory.path]),
            serverLocator: .init(environment: ["SCRCPY_SERVER_PATH": "/share/scrcpy-server"], fileExists: { _ in true }),
            runner: runner,
            launcher: launcher,
            connect: { _ in channel },
            scid: { Self.scid },
            timeout: timeout
        )
        return .init(clipboard: clipboard, runner: runner, launcher: launcher, channel: channel, scrcpyDirectory: directory)
    }

    private static func installedScrcpy() throws -> URL {
        let directory: URL = FileManager.default.temporaryDirectory.appending(path: "berth-scrcpy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let binary: URL = directory.appending(path: "scrcpy")
        FileManager.default.createFile(atPath: binary.path, contents: Data(), attributes: [.posixPermissions: 0o755])
        return directory
    }

    @Test
    func `reads the text, then removes the forward and stops the server`() async throws {
        let rig: Rig = try Self.rig()
        defer { rig.removeScrcpy() }

        let text: String? = try await rig.clipboard.text(serial: Self.serial)

        #expect(text == "hello")
        #expect(rig.runner.calls == [
            ["--version"],
            ["-s", Self.serial, "push", "/share/scrcpy-server", "/data/local/tmp/berth-scrcpy-server.jar"],
            ["-s", Self.serial, "forward", "tcp:0", Self.socket],
            Self.removeForward
        ])
        #expect(rig.launcher.launches == [ScrcpyServerCommand(version: "5.0.1", scid: Self.scid).adbArguments(serial: Self.serial)])
        #expect(rig.launcher.server.stopCount == 1)
        #expect(rig.channel.written == [[8, 0]])
    }

    @Test
    func `an empty clipboard reads as nil`() async throws {
        let rig: Rig = try Self.rig(script: [.bytes([0]), .bytes(ScrcpyDeviceMessageTests.clipboard(""))])
        defer { rig.removeScrcpy() }

        #expect(try await rig.clipboard.text(serial: Self.serial) == nil)
    }

    @Test
    func `a missing scrcpy stops before any adb call`() async throws {
        let empty: URL = FileManager.default.temporaryDirectory.appending(path: "berth-none-\(UUID().uuidString)")
        let rig: Rig = try Self.rig(scrcpyDirectory: empty)
        defer { rig.removeScrcpy() }

        await #expect(throws: DeviceClipboardError.scrcpyNotFound) {
            try await rig.clipboard.text(serial: Self.serial)
        }
        #expect(rig.runner.calls.isEmpty)
    }

    @Test
    func `a missing server file stops before any adb call`() async throws {
        let directory: URL = try Self.installedScrcpy()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clipboard: ScrcpyDeviceClipboard = .init(
            adb: "/sdk/adb",
            scrcpy: .init(environment: ["PATH": ""], fallbackDirectories: [directory.path]),
            serverLocator: .init(environment: ["SCRCPY_SERVER_PATH": "/share/scrcpy-server"], fileExists: { _ in false })
        )

        await #expect(throws: DeviceClipboardError.serverNotFound) {
            try await clipboard.text(serial: Self.serial)
        }
    }

    @Test
    func `a hanging scrcpy version is a timeout, not an unreadable version`() async throws {
        let rig: Rig = try Self.rig(failing: { $0 == ["--version"] ? FakeCommandRunner.hung() : nil })
        defer { rig.removeScrcpy() }

        await #expect(throws: DeviceClipboardError.timedOut(serial: Self.serial)) {
            try await rig.clipboard.text(serial: Self.serial)
        }
    }

    @Test
    func `an unreadable scrcpy version fails`() async throws {
        let rig: Rig = try Self.rig(failing: { $0 == ["--version"] ? FakeCommandRunner.ok("garbage") : nil })
        defer { rig.removeScrcpy() }

        await #expect(throws: DeviceClipboardError.failed(line: "cannot read the scrcpy version")) {
            try await rig.clipboard.text(serial: Self.serial)
        }
    }

    @Test
    func `a failed push shows adb's line and touches no forward and no server`() async throws {
        let rig: Rig = try Self.rig(failing: { $0.contains("push") ? FakeCommandRunner.failure("adb: error: device offline") : nil })
        defer { rig.removeScrcpy() }

        await #expect(throws: DeviceClipboardError.failed(line: "adb: error: device offline")) {
            try await rig.clipboard.text(serial: Self.serial)
        }
        #expect(rig.runner.calls.allSatisfy { !$0.contains("forward") })
        #expect(rig.launcher.launches.isEmpty)
    }

    @Test
    func `a failed forward looks the forward up by socket name and removes it`() async throws {
        let rig: Rig = try Self.rig(failing: { $0.contains("tcp:0") ? FakeCommandRunner.failure("error: closed") : nil })
        defer { rig.removeScrcpy() }

        await #expect(throws: DeviceClipboardError.failed(line: "error: closed")) {
            try await rig.clipboard.text(serial: Self.serial)
        }
        #expect(rig.runner.calls.contains(["forward", "--list"]))
        #expect(rig.runner.calls.contains(Self.removeForward))
        #expect(rig.launcher.launches.isEmpty)
    }

    @Test
    func `a forward that times out is removed by socket name`() async throws {
        let rig: Rig = try Self.rig(failing: { $0.contains("tcp:0") ? FakeCommandRunner.hung() : nil })
        defer { rig.removeScrcpy() }

        await #expect(throws: DeviceClipboardError.timedOut(serial: Self.serial)) {
            try await rig.clipboard.text(serial: Self.serial)
        }
        #expect(rig.runner.calls.contains(Self.removeForward))
    }

    @Test
    func `a server that cannot launch still removes the forward`() async throws {
        let rig: Rig = try Self.rig(launcherRefuses: true)
        defer { rig.removeScrcpy() }

        await #expect(throws: FakeScrcpyServerLauncher.Refused.self) {
            try await rig.clipboard.text(serial: Self.serial)
        }
        #expect(rig.runner.calls.contains(Self.removeForward))
    }

    @Test
    func `a read that times out stops the server, removes the forward and ends with the timeout`() async throws {
        let rig: Rig = try Self.rig(script: [.bytes([0]), .bytes([0, 0, 0])])
        defer { rig.removeScrcpy() }

        await #expect(throws: DeviceClipboardError.timedOut(serial: Self.serial)) {
            try await rig.clipboard.text(serial: Self.serial)
        }
        #expect(rig.launcher.server.stopCount == 1)
        #expect(rig.runner.calls.contains(Self.removeForward))
    }

    @Test
    func `a server that had to be terminated is killed on the device by its scid`() async throws {
        let rig: Rig = try Self.rig(server: .init(exitsOnItsOwn: false))
        defer { rig.removeScrcpy() }

        _ = try await rig.clipboard.text(serial: Self.serial)

        #expect(rig.runner.calls.contains(ScrcpyServerCommand(version: "5.0.1", scid: Self.scid).killArguments(serial: Self.serial)))
    }

    @Test
    func `a server that exited on its own is not killed`() async throws {
        let rig: Rig = try Self.rig()
        defer { rig.removeScrcpy() }

        _ = try await rig.clipboard.text(serial: Self.serial)

        #expect(rig.runner.calls.allSatisfy { !$0.contains { $0.contains("pkill") } })
    }
}
