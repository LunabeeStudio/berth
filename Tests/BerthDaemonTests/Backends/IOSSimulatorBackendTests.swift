import BerthCore
@testable import BerthDaemon
import Foundation
import Testing

@Suite
struct IOSSimulatorBackendTests {
    private static let listing = """
    {"devices": {
      "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
        {"udid": "A1", "name": "berth-iPhone 17-1", "state": "Booted", "isAvailable": true},
        {"udid": "A2", "name": "berth-iPhone 17-2", "state": "Shutdown", "isAvailable": true},
        {"udid": "U1", "name": "iPhone 18 Pro", "state": "Booted", "isAvailable": true}
      ],
      "com.apple.CoreSimulator.SimRuntime.iOS-15-0": [
        {"udid": "X1", "name": "berth-iPhone 17-3", "state": "Booted", "isAvailable": false}
      ]
    }}
    """

    @Test
    func `parses devices and drops unavailable runtimes`() throws {
        let devices = try #require(IOSSimulatorBackend.parseDevices(Data(Self.listing.utf8)))
        #expect(Set(devices.map(\.udid)) == ["A1", "A2", "U1"])
        #expect(devices.first { $0.udid == "A1" }?.isBooted == true)
        #expect(devices.first { $0.udid == "A2" }?.isBooted == false)
    }

    @Test
    func `live serials keep only booted berth devices`() throws {
        let devices = try #require(IOSSimulatorBackend.parseDevices(Data(Self.listing.utf8)))
        #expect(IOSSimulatorBackend.liveSerials(in: devices) == ["A1"])
    }

    @Test
    func `malformed listing parses to nil`() {
        #expect(IOSSimulatorBackend.parseDevices(Data("nope".utf8)) == nil)
    }

    @Test
    func `device names follow the berth convention`() {
        #expect(IOSSimulatorBackend.deviceName(simulator: "iPhone 17", index: 2) == "berth-iPhone 17-2")
    }

    @Test
    func `unprovisioned simulator is unavailable and has no serial`() {
        let config = Config(pool: [PoolEntry(name: "iPhone Bogus", platform: .ios, maxInstances: 1)])
        let backend = IOSSimulatorBackend(config: config)
        #expect(backend.unavailableReason(model: "iPhone Bogus") != nil)
        #expect(backend.nextSerial(model: "iPhone Bogus", taken: []) == nil)
    }

    @Test
    func `launch refuses a device berth does not own`() async {
        let backend = IOSSimulatorBackend(config: Config())
        await #expect(throws: BackendError.self) {
            _ = try await backend.launch(serial: "U1", model: "iPhone 18 Pro", windowed: false)
        }
    }
}
