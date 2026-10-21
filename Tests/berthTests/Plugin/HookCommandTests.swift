import Foundation
import Testing

@Suite
struct HookCommandTests {
    private static let warning: String = "berth not found on PATH or in ~/.local/bin: the device guard is off. Install: https://github.com/LunabeeStudio/berth#install"

    @Test
    func `guard falls back to the local bin berth and keeps its exit code`() throws {
        let sandbox: Sandbox = try .init()
        defer { sandbox.cleanup() }
        try sandbox.installFake(at: sandbox.localBerth, exitCode: 2)
        let outcome: Outcome = try Self.run("PreToolUse", sandbox: sandbox, stdin: "payload")
        #expect(outcome.status == 2)
        #expect(try String(contentsOf: sandbox.localMarker, encoding: .utf8) == "\(sandbox.localBerth.path) guard\npayload")
    }

    @Test
    func `guard prefers berth on PATH`() throws {
        let sandbox: Sandbox = try .init()
        defer { sandbox.cleanup() }
        try sandbox.installFake(at: sandbox.localBerth, exitCode: 0)
        try sandbox.installFake(at: sandbox.pathBerth, exitCode: 0)
        _ = try Self.run("PreToolUse", sandbox: sandbox, berthOnPath: true)
        #expect(FileManager.default.fileExists(atPath: sandbox.pathMarker.path))
        #expect(!FileManager.default.fileExists(atPath: sandbox.localMarker.path))
    }

    @Test
    func `guard allows silently without berth`() throws {
        let sandbox: Sandbox = try .init()
        defer { sandbox.cleanup() }
        let outcome: Outcome = try Self.run("PreToolUse", sandbox: sandbox)
        #expect(outcome.status == 0)
        #expect(outcome.stdout.isEmpty)
        #expect(outcome.stderr.isEmpty)
    }

    @Test
    func `session start exports the local bin to the session`() throws {
        let sandbox: Sandbox = try .init()
        defer { sandbox.cleanup() }
        try sandbox.installFake(at: sandbox.localBerth, exitCode: 0)
        let outcome: Outcome = try Self.run("SessionStart", sandbox: sandbox, withEnvFile: true)
        #expect(outcome.status == 0)
        #expect(outcome.stdout.isEmpty)
        #expect(try String(contentsOf: sandbox.envFile, encoding: .utf8) == "export PATH=\"$HOME/.local/bin:$PATH\"\n")
    }

    @Test
    func `session start without an env file stays silent`() throws {
        let sandbox: Sandbox = try .init()
        defer { sandbox.cleanup() }
        try sandbox.installFake(at: sandbox.localBerth, exitCode: 0)
        let outcome: Outcome = try Self.run("SessionStart", sandbox: sandbox)
        #expect(outcome.status == 0)
        #expect(outcome.stdout.isEmpty)
    }

    @Test
    func `session start leaves the session alone when berth is on PATH`() throws {
        let sandbox: Sandbox = try .init()
        defer { sandbox.cleanup() }
        try sandbox.installFake(at: sandbox.pathBerth, exitCode: 0)
        let outcome: Outcome = try Self.run("SessionStart", sandbox: sandbox, berthOnPath: true, withEnvFile: true)
        #expect(outcome.status == 0)
        #expect(outcome.stdout.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: sandbox.envFile.path))
    }

    @Test
    func `session start warns once when berth is nowhere`() throws {
        let sandbox: Sandbox = try .init()
        defer { sandbox.cleanup() }
        let outcome: Outcome = try Self.run("SessionStart", sandbox: sandbox, withEnvFile: true)
        #expect(outcome.status == 0)
        let message: [String: Any]? = try JSONSerialization.jsonObject(with: Data(outcome.stdout.utf8)) as? [String: Any]
        #expect(message?["systemMessage"] as? String == Self.warning)
        #expect(!FileManager.default.fileExists(atPath: sandbox.envFile.path))
    }
}

private extension HookCommandTests {
    struct Outcome {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    struct Sandbox {
        let dir: URL
        let home: URL
        let pathBin: URL
        let envFile: URL

        init() throws {
            dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            home = dir.appendingPathComponent("home")
            pathBin = dir.appendingPathComponent("bin")
            envFile = dir.appendingPathComponent("env")
            try FileManager.default.createDirectory(at: home.appendingPathComponent(".local/bin"), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: pathBin, withIntermediateDirectories: true)
        }

        var localBerth: URL { home.appendingPathComponent(".local/bin/berth") }
        var pathBerth: URL { pathBin.appendingPathComponent("berth") }
        var localMarker: URL { home.appendingPathComponent(".local/bin/marker") }
        var pathMarker: URL { pathBin.appendingPathComponent("marker") }

        func installFake(at berth: URL, exitCode: Int32) throws {
            let marker: URL = berth.deletingLastPathComponent().appendingPathComponent("marker")
            let script: String = "#!/bin/sh\necho \"$0 $@\" > '\(marker.path)'\ncat >> '\(marker.path)'\nexit \(exitCode)\n"
            try script.write(to: berth, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: berth.path)
        }

        func cleanup() {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    static func command(event: String) throws -> String {
        let hooks: [String: Any]? = try RepoFile.json("claude-plugin/hooks/hooks.json")?["hooks"] as? [String: Any]
        let groups: [[String: Any]]? = hooks?[event] as? [[String: Any]]
        let entries: [[String: Any]]? = groups?.first?["hooks"] as? [[String: Any]]
        return try #require(entries?.first?["command"] as? String)
    }

    static func run(_ event: String, sandbox: Sandbox, berthOnPath: Bool = false, withEnvFile: Bool = false, stdin: String = "") throws -> Outcome {
        let process: Process = .init()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", try command(event: event)]
        var env: [String: String] = ["HOME": sandbox.home.path, "PATH": berthOnPath ? "\(sandbox.pathBin.path):/usr/bin:/bin" : "/usr/bin:/bin"]
        if withEnvFile { env["CLAUDE_ENV_FILE"] = sandbox.envFile.path }
        process.environment = env
        let input: Pipe = .init()
        let out: Pipe = .init()
        let err: Pipe = .init()
        process.standardInput = input
        process.standardOutput = out
        process.standardError = err
        try process.run()
        try input.fileHandleForWriting.write(contentsOf: Data(stdin.utf8))
        try input.fileHandleForWriting.close()
        let stdout: Data = out.fileHandleForReading.readDataToEndOfFile()
        let stderr: Data = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Outcome(status: process.terminationStatus, stdout: String(decoding: stdout, as: UTF8.self), stderr: String(decoding: stderr, as: UTF8.self))
    }
}
