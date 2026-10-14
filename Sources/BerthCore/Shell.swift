import Foundation
import Synchronization

public struct ShellResult: Sendable {
    public var status: Int32
    public var stdout: String
    public var stderr: String
    public var timedOut: Bool

    public var succeeded: Bool { status == 0 && !timedOut }
    public var trimmedOutput: String { stdout.trimmingCharacters(in: .whitespacesAndNewlines) }
}

public enum ShellError: Error, CustomStringConvertible {
    case launchFailed(String, Error)

    public var description: String {
        switch self {
        case let .launchFailed(exe, error): "cannot launch \(exe): \(error)"
        }
    }
}

private final class ProcessBox: @unchecked Sendable {
    let process = Process()
}

public enum Shell {
    /// Temp files, not pipes: an `adb` server forked by the command would inherit a pipe and keep it open forever.
    public static func run(_ executable: String, _ arguments: [String], timeout: Duration = .seconds(60)) async throws -> ShellResult {
        let tmp = FileManager.default.temporaryDirectory
        let id = UUID().uuidString
        let outURL = tmp.appending(path: "berth-\(id).out")
        let errURL = tmp.appending(path: "berth-\(id).err")
        FileManager.default.createFile(atPath: outURL.path, contents: nil)
        FileManager.default.createFile(atPath: errURL.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: outURL)
            try? FileManager.default.removeItem(at: errURL)
        }
        let outHandle = try FileHandle(forWritingTo: outURL)
        let errHandle = try FileHandle(forWritingTo: errURL)

        let box = ProcessBox()
        box.process.executableURL = URL(fileURLWithPath: executable)
        box.process.arguments = arguments
        box.process.standardInput = FileHandle.nullDevice
        box.process.standardOutput = outHandle
        box.process.standardError = errHandle

        let (exits, exitContinuation) = AsyncStream.makeStream(of: Int32.self)
        box.process.terminationHandler = { process in
            exitContinuation.yield(process.terminationStatus)
            exitContinuation.finish()
        }
        do {
            try box.process.run()
        } catch {
            throw ShellError.launchFailed(executable, error)
        }

        let timedOut = TimeoutFlag()
        let watchdog = Task {
            try await Task.sleep(for: timeout)
            timedOut.set()
            box.process.terminate()
        }
        var status: Int32 = -1
        for await code in exits { status = code }
        watchdog.cancel()
        try? outHandle.close()
        try? errHandle.close()

        return ShellResult(
            status: status,
            stdout: (try? String(contentsOf: outURL, encoding: .utf8)) ?? "",
            stderr: (try? String(contentsOf: errURL, encoding: .utf8)) ?? "",
            timedOut: timedOut.isSet
        )
    }
}

public final class TimeoutFlag: Sendable {
    private let storage = Mutex(false)

    public init() {}
    public func set() { storage.withLock { $0 = true } }
    public var isSet: Bool { storage.withLock { $0 } }
}
