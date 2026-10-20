import Foundation
import Testing

@testable import BerthCore

@Suite
struct SpawnTests {
    @Test
    func `detached spawn passes the given environment to the child`() throws {
        let log: URL = FileManager.default.temporaryDirectory.appending(path: "spawn-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: log) }

        let pid: pid_t = try Spawn.detached("/bin/sh", ["-c", "echo $BERTH_FOO"], log: log, environment: ["BERTH_FOO": "bar"])
        var status: Int32 = 0
        waitpid(pid, &status, 0)

        #expect(try String(contentsOf: log, encoding: .utf8) == "bar\n")
    }
}
