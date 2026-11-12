import BerthCore
import Foundation
import Testing

@testable import BerthBar

@MainActor
@Suite
struct LaunchAtLoginTests {
    @Test
    func `enable then disable round trips through the plist file`() {
        let agent: LaunchAgent = .temporary(label: "com.berth.bar.test")
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
        let agent: LaunchAgent = .temporary(label: "com.berth.bar.test")
        defer { try? FileManager.default.removeItem(at: agent.plist.deletingLastPathComponent()) }
        let login: LaunchAtLogin = .init(agent: agent, executable: "/x", environment: [:])

        try agent.write(["Label": agent.label])
        login.refresh()

        #expect(login.isEnabled)
    }
}
