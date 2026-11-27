@testable import BerthDaemon
import Synchronization

final class FakeUsbmuxService: UsbmuxService, Sendable {
    private struct State {
        var devices: [UsbmuxDevice]?
        var trusted: Set<String> = []
        var lockdown: [Int: LockdownValues] = [:]
        var lockdownCalls: [Int] = []
    }

    private let state: Mutex<State>

    var lockdownCalls: [Int] { state.withLock { $0.lockdownCalls } }

    init(devices: [UsbmuxDevice]? = []) {
        state = .init(State(devices: devices))
    }

    func attach(_ devices: [UsbmuxDevice]?) {
        state.withLock { $0.devices = devices }
    }

    func trust(_ udid: String) {
        state.withLock { _ = $0.trusted.insert(udid) }
    }

    func setLockdown(_ values: LockdownValues?, deviceID: Int) {
        state.withLock { $0.lockdown[deviceID] = values }
    }

    func usbDevices() throws -> [UsbmuxDevice] {
        guard let devices = state.withLock({ $0.devices }) else { throw UsbmuxError.unavailable }
        return devices
    }

    func isTrusted(udid: String) throws -> Bool {
        state.withLock { $0.trusted.contains(udid) }
    }

    func lockdownValues(deviceID: Int) throws -> LockdownValues {
        try state.withLock { state in
            state.lockdownCalls.append(deviceID)
            guard let values = state.lockdown[deviceID] else { throw UsbmuxError.closed }
            return values
        }
    }
}
