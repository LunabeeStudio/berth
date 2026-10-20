import BerthCore

public protocol DeviceBackend: Sendable {
    /// Non-nil when no device can ever be provided for `model`, so claims must fail instead of waiting.
    func unavailableReason(model: String) -> String?
    func nextSerial(model: String, taken: Set<String>) -> String?
    func launch(serial: String, model: String, windowed: Bool) async throws -> Int32?
    func waitReady(serial: String, pid: Int32?) async throws
    /// Returns the PID now serving `serial` (a reset may restart the device).
    func reset(serial: String, model: String, pid: Int32?, windowed: Bool) async throws -> Int32?
    func shutdown(serial: String, pid: Int32?) async
    func liveSerials() async -> Set<String>?
    func isProcessAlive(_ pid: Int32) -> Bool
}

public extension DeviceBackend {
    func unavailableReason(model: String) -> String? { nil }
}
