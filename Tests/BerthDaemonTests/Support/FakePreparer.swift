@testable import BerthDaemon
import Foundation
import Synchronization

final class FakePreparer: AVDPreparing {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    private let state: Mutex<State> = .init(State())

    struct State {
        var avds: [String] = []
        var live: Set<String> = []
        var names: [String: String] = [:]
        var failure: String?
        var hold: Bool = false
        var calls: [String] = []
        var cancelled: [String] = []
        var completed: [String] = []
    }

    init(avds: [String]) {
        state.withLock { $0.avds = avds }
    }

    var calls: [String] { state.withLock { $0.calls } }
    var cancelled: [String] { state.withLock { $0.cancelled } }
    var completed: [String] { state.withLock { $0.completed } }

    func holdPrepares(_ hold: Bool) { state.withLock { $0.hold = hold } }
    func failPrepares(_ message: String) { state.withLock { $0.failure = message } }
    func setLive(_ serials: Set<String>) { state.withLock { $0.live = serials } }
    func setName(_ name: String, of serial: String) { state.withLock { $0.names[serial] = name } }

    func knownAVDs() async -> [String] { state.withLock { $0.avds } }
    func liveSerials() async -> Set<String> { state.withLock { $0.live } }
    func avdName(serial: String) async -> String? { state.withLock { $0.names[serial] } }

    func prepare(avd: String, serial: String, settle: Int, progress: @Sendable (String) -> Void) async throws {
        state.withLock { $0.calls.append(serial) }
        progress("cold booting \(avd) as \(serial)")
        while state.withLock({ $0.hold }) {
            do {
                try await Task.sleep(for: .milliseconds(5))
            } catch {
                state.withLock { $0.cancelled.append(serial) }
                throw error
            }
        }
        if let failure = state.withLock({ $0.failure }) { throw Failure(description: failure) }
        state.withLock { $0.completed.append(serial) }
    }
}
