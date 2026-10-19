import BerthCore

public struct DeviceRouter: DeviceBackend {
    private let android: any DeviceBackend
    private let ios: any DeviceBackend
    private let config: Config

    public init(config: Config, android: any DeviceBackend, ios: any DeviceBackend) {
        self.config = config
        self.android = android
        self.ios = ios
    }

    private func backend(forModel model: String) -> any DeviceBackend {
        config.platform(of: model) == .ios ? ios : android
    }

    private func backend(forSerial serial: String) -> any DeviceBackend {
        serial.hasPrefix("emulator-") ? android : ios
    }

    public func unavailableReason(model: String) -> String? {
        backend(forModel: model).unavailableReason(model: model)
    }

    public func nextSerial(model: String, taken: Set<String>) -> String? {
        backend(forModel: model).nextSerial(model: model, taken: taken)
    }

    public func launch(serial: String, model: String, windowed: Bool) async throws -> Int32? {
        try await backend(forModel: model).launch(serial: serial, model: model, windowed: windowed)
    }

    public func waitReady(serial: String, pid: Int32?) async throws {
        try await backend(forSerial: serial).waitReady(serial: serial, pid: pid)
    }

    public func reset(serial: String, model: String, pid: Int32?, windowed: Bool) async throws -> Int32? {
        try await backend(forModel: model).reset(serial: serial, model: model, pid: pid, windowed: windowed)
    }

    public func shutdown(serial: String, pid: Int32?) async {
        await backend(forSerial: serial).shutdown(serial: serial, pid: pid)
    }

    public func liveSerials() async -> Set<String>? {
        var live: Set<String> = []
        for platform in Set(config.pool.map(\.platform)) {
            guard let serials = await (platform == .ios ? ios : android).liveSerials() else { return nil }
            live.formUnion(serials)
        }
        return live
    }

    public func isProcessAlive(_ pid: Int32) -> Bool {
        android.isProcessAlive(pid)
    }
}
