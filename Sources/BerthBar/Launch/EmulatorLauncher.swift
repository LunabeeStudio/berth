import BerthCore
import Foundation
import Observation

@Observable
@MainActor
final class EmulatorLauncher {
    private(set) var error: String?
    private let actions: any DaemonActions

    init(actions: any DaemonActions = DaemonClientActions()) {
        self.actions = actions
    }

    nonisolated static var owner: Owner {
        let pid: Int32 = getpid()
        return Owner(pid: pid, startTime: ProcessInspector.details(of: pid)?.startTime, name: "berth-bar")
    }

    nonisolated static func request(model: String, owner: Owner) -> ClaimRequest {
        ClaimRequest(model: model, platform: .android, ttl: nil, label: "you", owner: owner, windowed: true)
    }

    @discardableResult
    func launch(model: String) -> Task<Void, Never> {
        error = nil
        let request: ClaimRequest = Self.request(model: model, owner: Self.owner)
        return Task { [weak self, actions] in
            do {
                try await actions.claim(request)
            } catch {
                self?.error = "\(error)"
            }
        }
    }

    @discardableResult
    func release(serial: String) -> Task<Void, Never> {
        Task { [weak self, actions] in
            do {
                try await actions.release(serial: serial)
            } catch {
                self?.error = "\(error)"
            }
        }
    }
}
