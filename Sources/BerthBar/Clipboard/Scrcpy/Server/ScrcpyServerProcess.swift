import Foundation

final class ScrcpyServerProcess: ScrcpyServer, @unchecked Sendable {
    private static let exitGrace: Duration = .seconds(1)
    private static let pollInterval: Duration = .milliseconds(50)

    private let process: Process = .init()
    private let log: URL

    init(adb: String, arguments: [String]) throws {
        log = FileManager.default.temporaryDirectory.appending(path: "berth-clipboard-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let handle: FileHandle = try .init(forWritingTo: log)
        process.executableURL = URL(fileURLWithPath: adb)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = handle
        process.standardError = handle
        do {
            try process.run()
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: log)
            throw DeviceClipboardError.failed(line: "cannot launch \(adb): \(error)")
        }
        try? handle.close()
    }

    func failureLine() -> String? {
        guard !process.isRunning else { return nil }
        let output: String = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        let last: String? = output.split(whereSeparator: \.isNewline).last.map { $0.trimmingCharacters(in: .whitespaces) }
        return last ?? "scrcpy server exited with status \(process.terminationStatus)"
    }

    /// The server exits by itself once its control socket closes: terminate the local adb only if it lingers.
    func stop() async -> Bool {
        defer { try? FileManager.default.removeItem(at: log) }
        let giveUp: ContinuousClock.Instant = .now + Self.exitGrace
        while process.isRunning, ContinuousClock.now < giveUp {
            try? await Task.sleep(for: Self.pollInterval)
        }
        guard process.isRunning else { return true }
        process.terminate()
        while process.isRunning {
            try? await Task.sleep(for: Self.pollInterval)
        }
        return false
    }
}
