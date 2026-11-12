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

    @Test
    func `bar plist runs the executable at load in the GUI session without keep alive`() {
        let plist: [String: Any] = makeAgent().barPlist(executable: "/opt/berth-bar", environment: [:])
        #expect(plist["Label"] as? String == "com.berth.test")
        #expect(plist["ProgramArguments"] as? [String] == ["/opt/berth-bar"])
        #expect(plist["RunAtLoad"] as? Bool == true)
        #expect(plist["LimitLoadToSessionType"] as? String == "Aqua")
        #expect(plist["ProcessType"] as? String == "Interactive")
        #expect(plist["KeepAlive"] == nil)
    }

    @Test
    func `bar plist carries BERTH_HOME only when set`() {
        let agent: LaunchAgent = makeAgent()
        let with: [String: Any] = agent.barPlist(executable: "/x", environment: [Paths.homeVariable: "/tmp/bh"])
        #expect((with["EnvironmentVariables"] as? [String: String]) == [Paths.homeVariable: "/tmp/bh"])
        #expect(agent.barPlist(executable: "/x", environment: [:])["EnvironmentVariables"] == nil)
        #expect(agent.barPlist(executable: "/x", environment: [Paths.homeVariable: ""])["EnvironmentVariables"] == nil)
    }

    @Test
    func `bar agent uses the com.berth.bar label`() {
        #expect(LaunchAgent.bar.label == "com.berth.bar")
    }

    @Test
    func `writeBar writes the same bytes for the same inputs`() throws {
        let first: LaunchAgent = makeAgent()
        let second: LaunchAgent = makeAgent()
        defer {
            try? FileManager.default.removeItem(at: first.plist.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.plist.deletingLastPathComponent())
        }
        try first.writeBar(executable: "/x", environment: [Paths.homeVariable: "/tmp/bh"])
        try second.writeBar(executable: "/x", environment: [Paths.homeVariable: "/tmp/bh"])
        #expect(try Data(contentsOf: first.plist) == Data(contentsOf: second.plist))
    }
}
