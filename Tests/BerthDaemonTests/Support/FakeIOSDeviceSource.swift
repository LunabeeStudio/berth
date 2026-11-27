import BerthCore
@testable import BerthDaemon
import Synchronization

final class FakeIOSDeviceSource: IOSDeviceSource, Sendable {
    private let current: Mutex<[IOSDevice]?>

    init(_ devices: [IOSDevice]? = []) {
        current = .init(devices)
    }

    func set(_ devices: [IOSDevice]?) {
        current.withLock { $0 = devices }
    }

    func devices() async -> [IOSDevice]? {
        current.withLock { $0 }
    }
}
