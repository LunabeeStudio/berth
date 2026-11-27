import Synchronization
import Testing

@testable import BerthBar
@testable import BerthCore

@MainActor
@Suite
struct PairFlowTests {
    private static let guid: String = "adb-R3CT312YV5B-AbCdEf"
    private static let pairing: MdnsService = .init(name: "berth-1", kind: .pairing, address: "192.168.4.29:37045")
    private static let connect: MdnsService = .init(name: "adb-R3CT312YV5B-AbCdEf", kind: .connect, address: "192.168.4.29:41234")
    private static let phone: PhysicalDevice = .mock(serial: "adb-R3CT312YV5B-AbCdEf._adb-tls-connect._tcp", model: "SM_S901B")

    private static func credentials() -> @Sendable () -> PairQR {
        let counter: Mutex<Int> = .init(0)
        return { counter.withLock { count in
            count += 1
            return PairQR(name: "berth-\(count)", password: "pw-\(count)")
        } }
    }

    private func flow(_ adb: FakeWifiAdb, clock: FakePairClock = .init()) -> PairFlow {
        .init(adb: adb, clock: clock, credentials: Self.credentials())
    }

    @Test
    func `a new flow shows the first qr`() {
        let flow: PairFlow = flow(.init())

        #expect(flow.state == .waitingForQR(PairQR(name: "berth-1", password: "pw-1")))
    }

    @Test
    func `the qr is found, paired, auto connected and the flow ends connected`() async {
        let adb: FakeWifiAdb = .init(.init(services: [Self.pairing], guid: Self.guid, appearances: [.init(call: "pair", device: Self.phone)]))
        let flow: PairFlow = flow(adb)

        await flow.start().value

        #expect(adb.calls.contains("pair 192.168.4.29:37045 pw-1"))
        #expect(!adb.calls.contains { $0.hasPrefix("connect") })
        #expect(flow.state == .connected(Self.phone))
    }

    @Test
    func `only a pairing service with our name is taken`() async {
        let other: MdnsService = .init(name: "studio-xyz", kind: .pairing, address: "192.168.4.50:37045")
        let ours: MdnsService = .init(name: "berth-1", kind: .connect, address: "192.168.4.29:41234")
        let adb: FakeWifiAdb = .init(.init(services: [other, ours]))
        let flow: PairFlow = flow(adb)

        await flow.start().value

        #expect(flow.state == .notFound)
        #expect(!adb.calls.contains { $0.hasPrefix("pair") })
    }

    @Test
    func `no phone for two minutes shows not found`() async {
        let adb: FakeWifiAdb = .init()
        let clock: FakePairClock = .init()
        let flow: PairFlow = flow(adb, clock: clock)

        await flow.start().value

        #expect(flow.state == .notFound)
        #expect(clock.now() == .seconds(120))
        #expect(adb.calls.filter { $0 == "mdns" }.count == 121)
    }

    @Test
    func `a slow adb does not stretch the two minutes`() async {
        let clock: FakePairClock = .init()
        let adb: FakeWifiAdb = .init(.init(), onCall: { clock.advance(.seconds(30)) })
        let flow: PairFlow = flow(adb, clock: clock)

        await flow.start().value

        #expect(flow.state == .notFound)
        #expect(adb.calls.filter { $0 == "mdns" }.count == 4)
        #expect(clock.now() < .seconds(130))
    }

    @Test
    func `retry makes a new name and password and polls again`() async {
        let adb: FakeWifiAdb = .init()
        let flow: PairFlow = flow(adb)
        await flow.start().value
        let second: MdnsService = .init(name: "berth-2", kind: .pairing, address: "192.168.4.29:37046")
        adb.update {
            $0.services = [second]
            $0.guid = Self.guid
            $0.appearances = [.init(call: "pair", device: Self.phone)]
        }

        await flow.retry().value

        #expect(adb.calls.contains("pair 192.168.4.29:37046 pw-2"))
        #expect(flow.state == .connected(Self.phone))
    }

    @Test
    func `retry shows the new qr while it polls`() async {
        let adb: FakeWifiAdb = .init()
        let flow: PairFlow = flow(adb, clock: .init(blocking: true))
        flow.retry()

        #expect(flow.state == .waitingForQR(PairQR(name: "berth-2", password: "pw-2")))
        flow.cancel()
    }

    @Test
    func `cancel during the qr wait stops the mdns polling`() async throws {
        let adb: FakeWifiAdb = .init()
        let flow: PairFlow = flow(adb, clock: .init(blocking: true))
        let polling: Task<Void, Never> = flow.start()
        while !adb.calls.contains("mdns") { try await Task.sleep(for: .milliseconds(5)) }

        flow.cancel()
        await polling.value
        let callsAtCancel: [String] = adb.calls
        try await Task.sleep(for: .milliseconds(100))

        #expect(adb.calls == callsAtCancel)
        #expect(callsAtCancel == ["mdns"])
    }

    @Test
    func `cancel stops a poll that never sleeps`() async {
        let adb: FakeWifiAdb = .init()
        let flow: PairFlow = flow(adb)
        let polling: Task<Void, Never> = flow.start()

        flow.cancel()
        await polling.value

        #expect(adb.calls.count < 2)
        #expect(flow.state != .notFound)
    }

    @Test
    func `the pairing code pairs and connects`() async {
        let adb: FakeWifiAdb = .init(.init(guid: Self.guid, appearances: [.init(call: "pair", device: Self.phone)]))
        let flow: PairFlow = flow(adb)
        flow.usePairingCode()
        flow.pairingAddress = " 192.168.4.29:37045 "
        flow.pairingCode = "123456"

        await flow.submitPairingCode().value

        #expect(adb.calls.contains("pair 192.168.4.29:37045 123456"))
        #expect(!adb.calls.contains("mdns"))
        #expect(flow.state == .connected(Self.phone))
    }

    @Test
    func `a wrong code shows adb's line and keeps both fields`() async {
        let adb: FakeWifiAdb = .init(.init(failingCall: "pair", failure: .failed(line: "Failed: Wrong password or connection was dropped")))
        let flow: PairFlow = flow(adb)
        flow.usePairingCode()
        flow.pairingAddress = "192.168.4.29:37045"
        flow.pairingCode = "000000"

        await flow.submitPairingCode().value

        #expect(flow.state == .codeEntry(error: "Failed: Wrong password or connection was dropped"))
        #expect(flow.pairingAddress == "192.168.4.29:37045")
        #expect(flow.pairingCode == "000000")
    }

    @Test
    func `a corrected code clears the error`() async {
        let adb: FakeWifiAdb = .init(.init(failingCall: "pair", failure: .failed(line: "Failed: Wrong password or connection was dropped")))
        let flow: PairFlow = flow(adb)
        flow.usePairingCode()
        flow.pairingAddress = "192.168.4.29:37045"
        flow.pairingCode = "000000"
        await flow.submitPairingCode().value
        adb.update {
            $0.failure = nil
            $0.guid = Self.guid
            $0.appearances = [.init(call: "pair", device: Self.phone)]
        }

        await flow.submitPairingCode().value

        #expect(flow.state == .connected(Self.phone))
    }

    @Test
    func `a failed qr pairing falls back to the code entry with the found address`() async {
        let adb: FakeWifiAdb = .init(.init(services: [Self.pairing], failingCall: "pair", failure: .failed(line: "Failed: Unable to start pairing client.")))
        let flow: PairFlow = flow(adb)

        await flow.start().value

        #expect(flow.state == .codeEntry(error: "Failed: Unable to start pairing client."))
        #expect(flow.pairingAddress == "192.168.4.29:37045")
    }

    @Test
    func `without auto connect the connect service of the phone's ip is used`() async {
        let adb: FakeWifiAdb = .init(.init(
            services: [Self.pairing, Self.connect],
            appearances: [.init(call: "connect", device: .mock(serial: "192.168.4.29:41234", model: "SM_S901B"))]
        ))
        let flow: PairFlow = flow(adb)

        await flow.start().value

        #expect(adb.calls.filter { $0 == "devices" }.count == 12)
        #expect(adb.calls.contains("connect 192.168.4.29:41234"))
        #expect(flow.state == .connected(.mock(serial: "192.168.4.29:41234", model: "SM_S901B")))
    }

    @Test
    func `a connect service of another ip is not used`() async {
        let elsewhere: MdnsService = .init(name: "adb-other", kind: .connect, address: "192.168.4.77:41234")
        let adb: FakeWifiAdb = .init(.init(services: [Self.pairing, elsewhere]))
        let flow: PairFlow = flow(adb)

        await flow.start().value

        #expect(!adb.calls.contains { $0.hasPrefix("connect") })
        #expect(flow.state == .manualConnect(error: nil))
    }

    @Test
    func `a wifi device that was already listed before pairing is not taken for the new phone`() async {
        let before: PhysicalDevice = .mock(serial: "192.168.100.200:5555", model: "Pixel_Fold")
        let adb: FakeWifiAdb = .init(.init(services: [Self.pairing], devices: [before]))
        let flow: PairFlow = flow(adb)

        await flow.start().value

        #expect(flow.state == .manualConnect(error: nil))
    }

    @Test
    func `a listed device of the phone's ip counts even if it was listed before`() async {
        let before: PhysicalDevice = .mock(serial: "192.168.4.29:5555", model: "SM_S901B")
        let adb: FakeWifiAdb = .init(.init(services: [Self.pairing], devices: [before]))
        let flow: PairFlow = flow(adb)

        await flow.start().value

        #expect(flow.state == .connected(before))
    }

    @Test
    func `a second phone auto connecting in the window is not taken for this one`() async {
        let other: PhysicalDevice = .mock(serial: "adb-9A2B3C4D5E-ZzZzZz._adb-tls-connect._tcp", model: "Pixel_Fold")
        let adb: FakeWifiAdb = .init(.init(services: [Self.pairing], guid: Self.guid, appearances: [.init(call: "pair", device: other)]))
        let flow: PairFlow = flow(adb)

        await flow.start().value

        #expect(flow.state == .manualConnect(error: nil))
    }

    @Test
    func `a connect service with another name is not used when adb gave the guid`() async {
        let elsewhere: MdnsService = .init(name: "adb-9A2B3C4D5E-ZzZzZz", kind: .connect, address: "192.168.4.29:41234")
        let adb: FakeWifiAdb = .init(.init(services: [Self.pairing, elsewhere], guid: Self.guid))
        let flow: PairFlow = flow(adb)

        await flow.start().value

        #expect(!adb.calls.contains { $0.hasPrefix("connect") })
        #expect(flow.state == .manualConnect(error: nil))
    }

    @Test
    func `an offline wifi device is not a connection`() async {
        let offline: PhysicalDevice = .mock(serial: "adb-R3CT312YV5B-AbCdEf._adb-tls-connect._tcp", model: nil, state: .offline)
        let adb: FakeWifiAdb = .init(.init(services: [Self.pairing], appearances: [.init(call: "pair", device: offline)]))
        let flow: PairFlow = flow(adb)

        await flow.start().value

        #expect(flow.state == .manualConnect(error: nil))
    }

    @Test
    func `when auto connect and the mdns lookup fail the manual address connects`() async {
        let adb: FakeWifiAdb = .init(.init(services: [Self.pairing]))
        let flow: PairFlow = flow(adb)
        await flow.start().value
        #expect(flow.state == .manualConnect(error: nil))
        adb.update { $0.appearances = [.init(call: "connect", device: .mock(serial: "192.168.4.29:40000", model: "SM_S901B"))] }
        flow.manualAddress = "192.168.4.29:40000"

        await flow.submitManualAddress().value

        #expect(adb.calls.last == "devices")
        #expect(adb.calls.contains("connect 192.168.4.29:40000"))
        #expect(flow.state == .connected(.mock(serial: "192.168.4.29:40000", model: "SM_S901B")))
    }

    @Test
    func `a failed manual connect shows adb's line and keeps the field`() async {
        let line: String = "failed to connect to '192.168.4.29:40000': Connection refused"
        let adb: FakeWifiAdb = .init(.init(services: [Self.pairing]))
        let flow: PairFlow = flow(adb)
        await flow.start().value
        adb.update {
            $0.failingCall = "connect"
            $0.failure = .failed(line: line)
        }
        flow.manualAddress = "192.168.4.29:40000"

        await flow.submitManualAddress().value

        #expect(flow.state == .manualConnect(error: line))
        #expect(flow.manualAddress == "192.168.4.29:40000")
    }

    @Test
    func `a manual connect that never lists the device shows an error and keeps the field`() async {
        let adb: FakeWifiAdb = .init(.init(services: [Self.pairing]))
        let flow: PairFlow = flow(adb)
        await flow.start().value
        flow.manualAddress = "192.168.4.29:40000"

        await flow.submitManualAddress().value

        #expect(flow.state == .manualConnect(error: "192.168.4.29:40000 is not in the adb device list"))
        #expect(flow.manualAddress == "192.168.4.29:40000")
    }
}
