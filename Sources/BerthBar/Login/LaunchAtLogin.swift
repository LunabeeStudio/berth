import BerthCore
import Foundation
import Observation

@Observable
@MainActor
final class LaunchAtLogin {
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
                    try? agent.writeBar(executable: executable, environment: environment)
                } else {
                    try? agent.remove()
                }
                installed = agent.isInstalled
            }
        }
    }

    init(
        agent: LaunchAgent = .bar,
        executable: String = LaunchAgent.currentExecutablePath(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.agent = agent
        self.executable = executable
        self.environment = environment
        installed = agent.isInstalled
    }

    func refresh() {
        withMutation(keyPath: \.isEnabled) {
            installed = agent.isInstalled
        }
    }
}
