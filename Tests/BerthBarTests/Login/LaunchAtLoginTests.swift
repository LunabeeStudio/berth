import BerthCore
import Foundation
import Testing

@testable import BerthBar

@MainActor
@Suite
struct LaunchAtLoginTests {
    private static func tempAgent() -> LaunchAgent {
        let directory: URL = FileManager.default.temporaryDirectory
            .appending(path: "berth-bar-login-\(UUID().uuidString)", directoryHint: .isDirectory)
        return .init(label: "com.berth.bar.test", directory: directory)
    }

    @Test
    func `plist runs the executable at load in the GUI session without keep alive`() {
        let plist: [String: Any] = LaunchAtLogin.plist(label: "com.berth.bar", executable: "/opt/berth-bar", environment: [:])
        #expect(plist["Label"] as? String == "com.berth.bar")
        #expect(plist["ProgramArguments"] as? [String] == ["/opt/berth-bar"])
        #expect(plist["RunAtLoad"] as? Bool == true)
        #expect(plist["LimitLoadToSessionType"] as? String == "Aqua")
        #expect(plist["ProcessType"] as? String == "Interactive")
        #expect(plist["KeepAlive"] == nil)
    }

    @Test
    func `plist carries BERTH_HOME only when set`() {
        let with: [String: Any] = LaunchAtLogin.plist(label: "l", executable: "/x", environment: [Paths.homeVariable: "/tmp/bh"])
        #expect((with["EnvironmentVariables"] as? [String: String]) == [Paths.homeVariable: "/tmp/bh"])
        #expect(LaunchAtLogin.plist(label: "l", executable: "/x", environment: [:])["EnvironmentVariables"] == nil)
        #expect(LaunchAtLogin.plist(label: "l", executable: "/x", environment: [Paths.homeVariable: ""])["EnvironmentVariables"] == nil)
    }

    @Test
    func `enable then disable round trips through the plist file`() {
        let agent: LaunchAgent = Self.tempAgent()
        defer { try? FileManager.default.removeItem(at: agent.plist.deletingLastPathComponent()) }
        let login: LaunchAtLogin = .init(agent: agent, executable: "/x", environment: [:])
        #expect(!login.isEnabled)

        login.isEnabled = true
        #expect(login.isEnabled)
        #expect(agent.isInstalled)

        login.isEnabled = false
        #expect(!login.isEnabled)
        #expect(!agent.isInstalled)
    }

    @Test
    func `refresh picks up a plist added outside the app`() throws {
        let agent: LaunchAgent = Self.tempAgent()
        defer { try? FileManager.default.removeItem(at: agent.plist.deletingLastPathComponent()) }
        let login: LaunchAtLogin = .init(agent: agent, executable: "/x", environment: [:])

        try agent.write(["Label": agent.label])
        login.refresh()

        #expect(login.isEnabled)
    }
}
