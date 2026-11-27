import Foundation

struct UsbmuxdService: UsbmuxService {
    let connector: any UsbmuxConnecting

    func usbDevices() throws -> [UsbmuxDevice] {
        try UsbmuxReply.usbDevices(in: exchange(.listDevices, on: connector.connect()))
    }

    func isTrusted(udid: String) throws -> Bool {
        try UsbmuxReply.isTrusted(pairRecord: exchange(.readPairRecord(udid: udid), on: connector.connect()))
    }

    func lockdownValues(deviceID: Int) throws -> LockdownValues {
        let connection: any UsbmuxConnection = try connector.connect()
        try UsbmuxReply.requireSuccess(result: exchange(.connect(deviceID: deviceID, port: LockdownKey.port), on: connection))
        return try LockdownValues(
            name: value(for: .deviceName, on: connection),
            productType: value(for: .productType, on: connection),
            osVersion: value(for: .productVersion, on: connection)
        )
    }
}

private extension UsbmuxdService {
    func exchange(_ message: UsbmuxMessage, on connection: any UsbmuxConnection) throws -> Data {
        try UsbmuxFraming.send(message.payload(), over: connection)
        return try UsbmuxFraming.receive(from: connection)
    }

    func value(for key: LockdownKey, on connection: any UsbmuxConnection) throws -> String? {
        try LockdownFraming.send(key.payload(), over: connection)
        return try LockdownKey.value(in: LockdownFraming.receive(from: connection))
    }
}
