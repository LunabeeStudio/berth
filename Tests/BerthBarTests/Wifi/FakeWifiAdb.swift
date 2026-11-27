import BerthCore
import Synchronization

@testable import BerthBar

final class FakeWifiAdb: WifiAdb {
    struct Appearance: Sendable {
        let call: String
        let device: PhysicalDevice
    }

    struct Script: Sendable {
        var services: [MdnsService] = []
        var address: String?
        var devices: [PhysicalDevice] = []
        var guid: String?
        var connectFailures: Int = 0
        var failingCall: String?
        var failure: WifiAdbError?
        var appearances: [Appearance] = []
    }

    private struct State {
        var script: Script
        var calls: [String] = []
    }

    private let state: Mutex<State>
    private let onCall: @Sendable () -> Void

    init(_ script: Script = .init(), onCall: @escaping @Sendable () -> Void = {}) {
        state = .init(State(script: script))
        self.onCall = onCall
    }

    private static func failIfScripted(_ state: State, _ verb: String) throws {
        guard let failure = state.script.failure, state.script.failingCall == nil || state.script.failingCall == verb else { return }
        throw failure
    }

    private static func appear(_ state: inout State, after verb: String) {
        let appearing: [PhysicalDevice] = state.script.appearances.filter { $0.call == verb }.map(\.device)
        state.script.devices.append(contentsOf: appearing)
    }

    var calls: [String] { state.withLock { $0.calls } }

    func update(_ change: (inout Script) -> Void) {
        state.withLock { change(&$0.script) }
    }

    func mdnsServices() async throws -> [MdnsService] {
        try record("mdns", "mdns") { $0.services }
    }

    func pair(address: String, code: String) async throws -> String? {
        try record("pair", "pair \(address) \(code)") { $0.guid }
    }

    func connect(address: String) async throws {
        onCall()
        try state.withLock {
            $0.calls.append("connect \(address)")
            if $0.script.connectFailures > 0 {
                $0.script.connectFailures -= 1
                throw WifiAdbError.failed(line: "failed to connect to '\(address)': Connection refused")
            }
            try Self.failIfScripted($0, "connect")
            Self.appear(&$0, after: "connect")
        }
    }

    func disconnect(serial: String) async throws {
        try record("disconnect", "disconnect \(serial)") { _ in }
    }

    func tcpip(serial: String, port: Int) async throws {
        try record("tcpip", "tcpip \(serial) \(port)") { _ in }
    }

    func wifiAddress(serial: String) async throws -> String? {
        try record("wifiAddress", "wifiAddress \(serial)") { $0.address }
    }

    func devices() async throws -> [PhysicalDevice] {
        try record("devices", "devices") { $0.devices }
    }

    private func record<Value>(_ verb: String, _ call: String, _ value: (Script) -> Value) throws -> Value {
        onCall()
        return try state.withLock {
            $0.calls.append(call)
            try Self.failIfScripted($0, verb)
            Self.appear(&$0, after: verb)
            return value($0.script)
        }
    }
}
