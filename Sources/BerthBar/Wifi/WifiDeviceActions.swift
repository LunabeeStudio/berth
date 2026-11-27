import Foundation
import Observation

@Observable
@MainActor
final class WifiDeviceActions {
    nonisolated static let usbPort: Int = 5555
    nonisolated static let connectAttempts: Int = 10
    nonisolated static let connectInterval: Duration = .seconds(1)

    private(set) var caption: String?
    private let adb: any WifiAdb
    private let sleep: @Sendable (Duration) async throws -> Void

    init(
        adb: any WifiAdb = SdkWifiAdb(),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.adb = adb
        self.sleep = sleep
    }

    private nonisolated static func switchToWifi(
        serial: String,
        adb: any WifiAdb,
        sleep: @Sendable (Duration) async throws -> Void
    ) async throws {
        guard let address = try await adb.wifiAddress(serial: serial) else {
            throw WifiAdbError.noWifiAddress(serial: serial)
        }
        try await adb.tcpip(serial: serial, port: usbPort)
        for _ in 1 ..< connectAttempts {
            do {
                return try await adb.connect(address: "\(address):\(usbPort)")
            } catch is WifiAdbError {
                try await sleep(connectInterval)
            }
        }
        try await adb.connect(address: "\(address):\(usbPort)")
    }

    @discardableResult
    func disconnect(serial: String) -> Task<Void, Never> {
        caption = nil
        return Task { [weak self, adb] in
            do {
                try await adb.disconnect(serial: serial)
            } catch {
                self?.caption = "\(error)"
            }
        }
    }

    @discardableResult
    func switchToWifi(serial: String) -> Task<Void, Never> {
        caption = nil
        return Task { [weak self, adb, sleep] in
            do {
                try await Self.switchToWifi(serial: serial, adb: adb, sleep: sleep)
            } catch {
                self?.caption = "\(error)"
            }
        }
    }
}
