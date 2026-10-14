import BerthCore
import Foundation

public enum BackendError: Error, CustomStringConvertible {
    case exited(String)
    case bootTimeout(String)
    case command(String, String)

    public var description: String {
        switch self {
        case let .exited(serial): "\(serial): emulator process exited during boot"
        case let .bootTimeout(serial): "\(serial): boot timed out"
        case let .command(command, output): "\(command) failed: \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
    }
}

public final class AndroidBackend: DeviceBackend {
    public let adb: String
    public let emulator: String
    public let snapshotName: String
    let bootTimeout: Duration

    public static let firstPort = 5554
    public static let lastPort = 5680

    public init(config: Config) {
        let sdk = config.resolvedSDKRoot
        adb = "\(sdk)/platform-tools/adb"
        emulator = "\(sdk)/emulator/emulator"
        snapshotName = config.snapshotName
        bootTimeout = .seconds(config.bootTimeoutSeconds)
    }

    public static func listAVDs(sdkRoot: String) async -> [String] {
        guard let result = try? await Shell.run("\(sdkRoot)/emulator/emulator", ["-list-avds"]) else { return [] }
        return result.stdout
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains(" ") && !$0.contains("|") }
    }

    public static func port(of serial: String) -> Int? {
        serial.split(separator: "-").last.flatMap { Int($0) }
    }

    public func nextSerial(model: String, taken: Set<String>) -> String? {
        stride(from: Self.firstPort, through: Self.lastPort, by: 2)
            .map { "emulator-\($0)" }
            .first { !taken.contains($0) }
    }

    public func launch(serial: String, model: String) async throws -> Int32? {
        guard let port = Self.port(of: serial) else { throw BackendError.command("launch", "bad serial \(serial)") }
        var arguments = ["-avd", model, "-port", String(port), "-read-only", "-no-window", "-no-boot-anim", "-no-audio"]
        if hasCleanSnapshot(model: model) {
            arguments += ["-snapshot", snapshotName, "-no-snapshot-save"]
        } else {
            Log.info("\(model): no '\(snapshotName)' snapshot, cold booting (run `berth prepare \(model)` for fast resets)")
            arguments += ["-no-snapshot"]
        }
        return try Spawn.detached(emulator, arguments, log: Paths.logs.appending(path: "\(serial).log"))
    }

    public func waitReady(serial: String, pid: Int32?) async throws {
        try await waitReady(serial: serial, pid: pid, timeout: bootTimeout)
    }

    public func waitReady(serial: String, pid: Int32?, timeout: Duration) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let pid, !isProcessAlive(pid) { throw BackendError.exited(serial) }
            let result = try? await Shell.run(adb, ["-s", serial, "shell", "getprop", "sys.boot_completed"], timeout: .seconds(10))
            if result?.trimmedOutput == "1" { return }
            try await Task.sleep(for: .seconds(2))
        }
        throw BackendError.bootTimeout(serial)
    }

    /// `snapshot load` is refused under -read-only, but a restart discards every write and boots from the clean snapshot in seconds.
    public func reset(serial: String, model: String, pid: Int32?) async throws -> Int32? {
        await shutdown(serial: serial, pid: pid)
        let newPID = try await launch(serial: serial, model: model)
        try await waitReady(serial: serial, pid: newPID)
        return newPID
    }

    public func shutdown(serial: String, pid: Int32?) async {
        _ = try? await Shell.run(adb, ["-s", serial, "emu", "kill"], timeout: .seconds(15))
        guard let pid else { return }
        for _ in 0..<40 {
            if !isProcessAlive(pid) { return }
            try? await Task.sleep(for: .milliseconds(500))
        }
        kill(pid, SIGTERM)
        try? await Task.sleep(for: .seconds(3))
        if isProcessAlive(pid) { kill(pid, SIGKILL) }
    }

    public func liveSerials() async -> Set<String>? {
        guard let result = try? await Shell.run(adb, ["devices"], timeout: .seconds(10)), result.succeeded else { return nil }
        return Set(
            result.stdout
                .split(whereSeparator: \.isNewline)
                .dropFirst()
                .compactMap { $0.split(whereSeparator: \.isWhitespace).first.map(String.init) }
                .filter { $0.hasPrefix("emulator-") }
        )
    }

    public func isProcessAlive(_ pid: Int32) -> Bool {
        ProcessInspector.isProcessAlive(pid)
    }

    public func avdName(serial: String) async -> String? {
        guard let result = try? await Shell.run(adb, ["-s", serial, "emu", "avd", "name"], timeout: .seconds(10)), result.succeeded else { return nil }
        return result.stdout.split(whereSeparator: \.isNewline).first.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    public func hasCleanSnapshot(model: String) -> Bool {
        FileManager.default.fileExists(atPath: Self.avdDirectory(model: model).appending(path: "snapshots/\(snapshotName)").path)
    }

    static var avdHome: URL {
        let env = ProcessInfo.processInfo.environment
        if let home = env["ANDROID_AVD_HOME"], !home.isEmpty { return URL(fileURLWithPath: home) }
        if let user = env["ANDROID_USER_HOME"], !user.isEmpty { return URL(fileURLWithPath: user).appending(path: "avd") }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: ".android/avd")
    }

    public static func avdDirectory(model: String) -> URL {
        let ini = avdHome.appending(path: "\(model).ini")
        if let contents = try? String(contentsOf: ini, encoding: .utf8),
           let line = contents.split(whereSeparator: \.isNewline).first(where: { $0.hasPrefix("path=") }) {
            return URL(fileURLWithPath: String(line.dropFirst("path=".count)))
        }
        return avdHome.appending(path: "\(model).avd")
    }
}
