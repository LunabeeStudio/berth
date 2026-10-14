import BerthCore
@testable import BerthDaemon
import Foundation
import Synchronization
import Testing

final class FakeBackend: DeviceBackend {
    private let state = Mutex(State())

    struct State {
        var live: Set<String> = []
        var failingModels: Set<String> = []
        var failReset = false
        var holdResets = false
        var unavailable: [String: String] = [:]
        var resets: [String] = []
        var shutdowns: [String] = []
    }

    func failBoot(_ model: String) { state.withLock { _ = $0.failingModels.insert(model) } }
    func markUnavailable(_ model: String, reason: String) { state.withLock { $0.unavailable[model] = reason } }
    func unavailableReason(model: String) -> String? { state.withLock { $0.unavailable[model] } }
    func holdResets(_ hold: Bool) { state.withLock { $0.holdResets = hold } }
    func isLive(_ serial: String) -> Bool { state.withLock { $0.live.contains(serial) } }
    func failResets() { state.withLock { $0.failReset = true } }
    func vanish(_ serial: String) { state.withLock { _ = $0.live.remove(serial) } }
    var resets: [String] { state.withLock { $0.resets } }
    var shutdowns: [String] { state.withLock { $0.shutdowns } }

    func nextSerial(model: String, taken: Set<String>) -> String? {
        if model.hasPrefix("iPhone") {
            return (1...9).map { "UDID-\($0)" }.first { !taken.contains($0) }
        }
        return stride(from: 5554, through: 5600, by: 2).map { "emulator-\($0)" }.first { !taken.contains($0) }
    }

    func launch(serial: String, model: String) async throws -> Int32? {
        if state.withLock({ $0.failingModels.contains(model) }) { throw BackendError.exited(serial) }
        state.withLock { _ = $0.live.insert(serial) }
        return nil
    }

    func waitReady(serial: String, pid: Int32?) async throws {}

    func reset(serial: String, model: String, pid: Int32?) async throws -> Int32? {
        try state.withLock {
            $0.resets.append(serial)
            if $0.failReset { throw BackendError.exited(serial) }
        }
        while state.withLock({ $0.holdResets }) { try await Task.sleep(for: .milliseconds(5)) }
        state.withLock { _ = $0.live.insert(serial) }
        return pid
    }

    func shutdown(serial: String, pid: Int32?) async {
        state.withLock {
            $0.shutdowns.append(serial)
            $0.live.remove(serial)
        }
    }

    func liveSerials() async -> Set<String>? { state.withLock { $0.live } }
    func isProcessAlive(_ pid: Int32) -> Bool { true }
}
