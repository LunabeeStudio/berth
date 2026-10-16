import BerthCore
import Foundation
import Observation

@Observable
@MainActor
final class LaunchAtLogin {
    static let label: String = "com.berth.bar"

    @ObservationIgnored private var installed: Bool
    @ObservationIgnored private let agent: LaunchAgent
    @ObservationIgnored private let executable: String
    @ObservationIgnored private let environment: [String: String]

    var isEnabled: Bool {
        get {
            access(keyPath: \.isEnabled)
            return installed
        }
        set {
            withMutation(keyPath: \.isEnabled) {
                if newValue {
                    try? agent.write(Self.plist(label: agent.label, executable: executable, environment: environment))
                } else {
                    try? agent.remove()
                }
                installed = agent.isInstalled
            }
        }
    }

    init(
        agent: LaunchAgent = .init(label: LaunchAtLogin.label),
        executable: String = LaunchAgent.currentExecutablePath(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.agent = agent
        self.executable = executable
        self.environment = environment
        installed = agent.isInstalled
    }

    nonisolated static func plist(label: String, executable: String, environment: [String: String]) -> [String: Any] {
        var contents: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
            "ProcessType": "Interactive",
        ]
        if let home = environment[Paths.homeVariable], !home.isEmpty {
            contents["EnvironmentVariables"] = [Paths.homeVariable: home]
        }
        return contents
    }

    func refresh() {
        withMutation(keyPath: \.isEnabled) {
            installed = agent.isInstalled
        }
    }
}
