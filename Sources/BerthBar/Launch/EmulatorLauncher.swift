import BerthCore
import Foundation
import Observation

@Observable
@MainActor
final class EmulatorLauncher {
    static let prepareSettleSeconds: Int = 20

    private(set) var error: String?
    private let actions: any DaemonActions
    private let plain: any PlainEmulatorLauncher

    init(actions: any DaemonActions = DaemonClientActions(), plain: any PlainEmulatorLauncher = SystemPlainEmulatorLauncher()) {
        self.actions = actions
        self.plain = plain
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
    func prepare(avd: String) -> Task<Void, Never> {
        error = nil
        let request: PrepareRequest = .init(avd: avd, settle: Self.prepareSettleSeconds)
        return Task { [weak self, actions] in
            do {
                try await actions.prepare(request)
            } catch {
                self?.error = "\(error)"
            }
        }
    }

    func launchPlain(avd: String) {
        error = nil
        do {
            try plain.launch(avd: avd)
        } catch {
            self.error = "\(error)"
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
