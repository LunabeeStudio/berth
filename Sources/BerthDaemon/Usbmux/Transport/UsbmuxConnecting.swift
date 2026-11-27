protocol UsbmuxConnecting: Sendable {
    func connect() throws -> any UsbmuxConnection
}
