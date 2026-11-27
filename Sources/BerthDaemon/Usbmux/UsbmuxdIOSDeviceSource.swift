import BerthCore
import Dispatch
import Synchronization

final class UsbmuxdIOSDeviceSource: IOSDeviceSource {
    private let service: any UsbmuxService
    private let lockdownCache: Mutex<[Int: LockdownValues]> = .init([:])

    convenience init(socketPath: String = "/var/run/usbmuxd", timeout: Duration = .seconds(2)) {
        self.init(service: UsbmuxdService(connector: UnixSocketConnector(path: socketPath, timeout: timeout)))
    }

    init(service: any UsbmuxService) {
        self.service = service
    }

    func devices() async -> [IOSDevice]? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async { continuation.resume(returning: self.poll()) }
        }
    }
}

private extension UsbmuxdIOSDeviceSource {
    /// Lockdown values are read once per attachment (usbmuxd `DeviceID`); a failed read is cached as empty until the phone is re-attached.
    func poll() -> [IOSDevice]? {
        do {
            var seen: Set<String> = []
            let attached: [UsbmuxDevice] = try service.usbDevices().filter { seen.insert($0.udid).inserted }
            let trust: [String: Bool] = try Dictionary(uniqueKeysWithValues: attached.map { ($0.udid, try service.isTrusted(udid: $0.udid)) })
            let known: [Int: LockdownValues] = lockdownCache.withLock { $0 }
            let current: [Int: LockdownValues] = Dictionary(
                attached.map { ($0.deviceID, known[$0.deviceID] ?? ((try? service.lockdownValues(deviceID: $0.deviceID)) ?? .unavailable)) },
                uniquingKeysWith: { first, _ in first }
            )
            lockdownCache.withLock { $0 = current }
            return attached.map { device in
                let values: LockdownValues = current[device.deviceID] ?? .unavailable
                return IOSDevice(
                    udid: device.udid,
                    name: values.name,
                    productType: values.productType,
                    osVersion: values.osVersion,
                    trusted: trust[device.udid] ?? false
                )
            }
        } catch {
            return nil
        }
    }
}
