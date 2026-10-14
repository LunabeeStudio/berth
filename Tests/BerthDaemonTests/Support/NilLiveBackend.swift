import BerthCore
@testable import BerthDaemon

final class NilLiveBackend: DeviceBackend {
    func nextSerial(model: String, taken: Set<String>) -> String? { nil }
    func launch(serial: String, model: String) async throws -> Int32? { nil }
    func waitReady(serial: String, pid: Int32?) async throws {}
    func reset(serial: String, model: String, pid: Int32?) async throws -> Int32? { nil }
    func shutdown(serial: String, pid: Int32?) async {}
    func liveSerials() async -> Set<String>? { nil }
    func isProcessAlive(_ pid: Int32) -> Bool { true }
}
