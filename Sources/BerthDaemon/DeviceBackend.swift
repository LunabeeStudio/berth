import BerthCore

public protocol DeviceBackend: Sendable {
    func nextSerial(model: String, taken: Set<String>) -> String?
    func launch(serial: String, model: String) async throws -> Int32?
    func waitReady(serial: String, pid: Int32?) async throws
    /// Returns the PID now serving `serial` (a reset may restart the device).
    func reset(serial: String, model: String, pid: Int32?) async throws -> Int32?
    func shutdown(serial: String, pid: Int32?) async
    func liveSerials() async -> Set<String>?
    func isProcessAlive(_ pid: Int32) -> Bool
}
