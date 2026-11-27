struct UnixSocketConnector: UsbmuxConnecting {
    let path: String
    let timeout: Duration

    func connect() throws -> any UsbmuxConnection {
        try UnixSocketConnection(path: path, timeout: timeout)
    }
}
