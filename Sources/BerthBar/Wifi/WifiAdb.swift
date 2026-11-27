import BerthCore

protocol WifiAdb: Sendable {
    func mdnsServices() async throws -> [MdnsService]
    @discardableResult
    func pair(address: String, code: String) async throws -> String?
    func connect(address: String) async throws
    func disconnect(serial: String) async throws
    func tcpip(serial: String, port: Int) async throws
    func wifiAddress(serial: String) async throws -> String?
    func devices() async throws -> [PhysicalDevice]
}
