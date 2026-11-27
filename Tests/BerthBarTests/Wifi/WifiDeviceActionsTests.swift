import BerthCore
import Synchronization
import Testing

@testable import BerthBar

@MainActor
@Suite
struct WifiDeviceActionsTests {
    private static let noSleep: @Sendable (Duration) async throws -> Void = { _ in }

    @Test
    func `a disconnect runs adb disconnect with the serial and shows no caption`() async {
        let adb: FakeWifiAdb = .init()
        let actions: WifiDeviceActions = .init(adb: adb, sleep: Self.noSleep)

        await actions.disconnect(serial: "192.168.100.200:5555").value

        #expect(adb.calls == ["disconnect 192.168.100.200:5555"])
        #expect(actions.caption == nil)
    }

    @Test
    func `a failed disconnect shows adb's line and the next one clears it`() async {
        let adb: FakeWifiAdb = .init(.init(failure: .failed(line: "error: no such device '192.168.100.200:5555'")))
        let actions: WifiDeviceActions = .init(adb: adb, sleep: Self.noSleep)

        await actions.disconnect(serial: "192.168.100.200:5555").value
        #expect(actions.caption == "error: no such device '192.168.100.200:5555'")

        adb.update { $0.failure = nil }
        await actions.disconnect(serial: "192.168.100.200:5555").value
        #expect(actions.caption == nil)
    }

    @Test
    func `a switch reads the address, restarts adbd in tcp mode, then connects on port 5555`() async {
        let adb: FakeWifiAdb = .init(.init(address: "192.168.4.29"))
        let actions: WifiDeviceActions = .init(adb: adb, sleep: Self.noSleep)

        await actions.switchToWifi(serial: "R3CT312YV5B").value

        #expect(adb.calls == ["wifiAddress R3CT312YV5B", "tcpip R3CT312YV5B 5555", "connect 192.168.4.29:5555"])
        #expect(actions.caption == nil)
    }

    @Test
    func `a switch without a wifi address shows the caption and never restarts adbd`() async {
        let adb: FakeWifiAdb = .init()
        let actions: WifiDeviceActions = .init(adb: adb, sleep: Self.noSleep)

        await actions.switchToWifi(serial: "R3CT312YV5B").value

        #expect(adb.calls == ["wifiAddress R3CT312YV5B"])
        #expect(actions.caption == "R3CT312YV5B: no Wi-Fi address, turn Wi-Fi on")
    }

    @Test
    func `a switch retries the connect until adbd is back`() async {
        let adb: FakeWifiAdb = .init(.init(address: "192.168.4.29", connectFailures: 3))
        let slept: Mutex<[Duration]> = .init([])
        let actions: WifiDeviceActions = .init(adb: adb, sleep: { duration in slept.withLock { $0.append(duration) } })

        await actions.switchToWifi(serial: "R3CT312YV5B").value

        #expect(adb.calls.filter { $0.hasPrefix("connect") }.count == 4)
        #expect(slept.withLock { $0 } == Array(repeating: .seconds(1), count: 3))
        #expect(actions.caption == nil)
    }

    @Test
    func `a connect that never succeeds shows adb's last line after the whole window`() async {
        let adb: FakeWifiAdb = .init(.init(address: "192.168.4.29", connectFailures: .max))
        let slept: Mutex<Int> = .init(0)
        let actions: WifiDeviceActions = .init(adb: adb, sleep: { _ in slept.withLock { $0 += 1 } })

        await actions.switchToWifi(serial: "R3CT312YV5B").value

        #expect(adb.calls.filter { $0.hasPrefix("connect") }.count == 10)
        #expect(slept.withLock { $0 } == 9)
        #expect(actions.caption == "failed to connect to '192.168.4.29:5555': Connection refused")
    }

    @Test
    func `a failing tcpip shows adb's line and never connects`() async {
        let adb: FakeWifiAdb = .init(.init(address: "192.168.4.29", failingCall: "tcpip", failure: .failed(line: "error: device offline")))
        let actions: WifiDeviceActions = .init(adb: adb, sleep: Self.noSleep)

        await actions.switchToWifi(serial: "R3CT312YV5B").value

        #expect(adb.calls == ["wifiAddress R3CT312YV5B", "tcpip R3CT312YV5B 5555"])
        #expect(actions.caption == "error: device offline")
    }
}
