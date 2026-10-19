import BerthCore
import Foundation
import Observation

@Observable
@MainActor
final class EmulatorLauncher {
    private(set) var error: String?

    nonisolated static var owner: Owner {
        let pid: Int32 = getpid()
        return Owner(pid: pid, startTime: ProcessInspector.details(of: pid)?.startTime, name: "berth-bar")
    }

    nonisolated static func request(model: String, owner: Owner) -> ClaimRequest {
        ClaimRequest(model: model, platform: .android, ttl: nil, label: "you", owner: owner, windowed: true)
    }

    func launch(model: String) {
        error = nil
        Task { [weak self] in
            do {
                _ = try await DaemonClient.claim(Self.request(model: model, owner: Self.owner), autoSpawn: false)
            } catch {
                self?.error = "\(error)"
            }
        }
    }

    func release(serial: String) {
        Task { [weak self] in
            do {
                try await DaemonClient.call(.release(target: serial), autoSpawn: false)
            } catch {
                self?.error = "\(error)"
            }
        }
    }
}
