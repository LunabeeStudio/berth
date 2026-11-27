protocol UsbmuxService: Sendable {
    func usbDevices() throws -> [UsbmuxDevice]
    func isTrusted(udid: String) throws -> Bool
    func lockdownValues(deviceID: Int) throws -> LockdownValues
}
