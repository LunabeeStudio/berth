import BerthCore
import Foundation

struct SystemMirrorLauncher: MirrorLauncher {
    private let adb: String

    init(adb: String = Self.defaultADB()) {
        self.adb = adb
    }

    static func defaultADB() -> String {
        let config: Config = (try? Config.load()) ?? .init()
        return config.adbPath
    }

    func launch(
        executable: String,
        arguments: [String],
        log: URL,
        onExit: @escaping @MainActor @Sendable (Int32) -> Void
    ) throws -> any MirrorProcess {
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let output: FileHandle = try .init(forWritingTo: log)
        let process: Process = .init()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(["ADB": adb]) { _, new in new }
        process.standardOutput = output
        process.standardError = output
        process.terminationHandler = { finished in
            let status: Int32 = finished.terminationStatus
            try? output.close()
            Task { @MainActor in onExit(status) }
        }
        do {
            try process.run()
        } catch {
            try? output.close()
            throw error
        }
        return SystemMirrorProcess(process: process)
    }
}
