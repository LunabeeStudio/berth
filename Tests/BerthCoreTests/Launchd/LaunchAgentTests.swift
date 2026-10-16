import Foundation
import Testing

@testable import BerthCore

@Suite
struct LaunchAgentTests {
    private func makeAgent() -> LaunchAgent {
        let directory: URL = FileManager.default.temporaryDirectory
            .appending(path: "berth-launchagent-\(UUID().uuidString)", directoryHint: .isDirectory)
        return .init(label: "com.berth.test", directory: directory)
    }

    @Test
    func `write creates a parsable plist and marks the agent installed`() throws {
        let agent: LaunchAgent = makeAgent()
        defer { try? FileManager.default.removeItem(at: agent.plist.deletingLastPathComponent()) }
        #expect(!agent.isInstalled)

        try agent.write(["Label": agent.label, "RunAtLoad": true])

        #expect(agent.isInstalled)
        let parsed: [String: Any]? = try PropertyListSerialization.propertyList(from: Data(contentsOf: agent.plist), format: nil) as? [String: Any]
        #expect(parsed?["Label"] as? String == "com.berth.test")
        #expect(parsed?["RunAtLoad"] as? Bool == true)
    }

    @Test
    func `remove deletes the plist`() throws {
        let agent: LaunchAgent = makeAgent()
        defer { try? FileManager.default.removeItem(at: agent.plist.deletingLastPathComponent()) }
        try agent.write(["Label": agent.label])

        try agent.remove()

        #expect(!agent.isInstalled)
    }

    @Test
    func `remove does not throw when absent`() throws {
        try makeAgent().remove()
    }

    @Test
    func `plist lives in the injected directory under the label`() {
        let agent: LaunchAgent = makeAgent()
        #expect(agent.plist.lastPathComponent == "com.berth.test.plist")
    }
}
