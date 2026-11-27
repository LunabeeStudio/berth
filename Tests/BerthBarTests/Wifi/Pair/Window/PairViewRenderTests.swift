import AppKit
import BerthCore
import SwiftUI
import Testing

@testable import BerthBar

@MainActor
@Suite
struct PairViewRenderTests {
    private static let phone: PhysicalDevice = .init(serial: "adb-R3CT312YV5B-AbCdEf._adb-tls-connect._tcp", model: "SM_S901B", state: .device)
    private static let pairingService: MdnsService = .init(name: "berth-qr7k2m4x", kind: .pairing, address: "192.168.4.29:37045")
    private static let guid: String = "adb-R3CT312YV5B-AbCdEf"

    private static func flow(_ adb: FakeWifiAdb, clock: FakePairClock = .init()) -> PairFlow {
        .init(adb: adb, clock: clock, credentials: { PairQR(name: "berth-qr7k2m4x", password: "pw9x4m2k7c3z") })
    }

    private static func render(_ flow: PairFlow, named name: String, appearance: NSAppearance.Name = .aqua) throws {
        let host: NSHostingView<PairView> = .init(rootView: PairView(flow: flow))
        host.appearance = NSAppearance(named: appearance)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let image: NSBitmapImageRep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        try PanelPNG.write(image, named: name)
        #expect(image.size.width == 400)
        #expect(image.pixelsHigh > 0)
    }

    @Test(arguments: [(NSAppearance.Name.aqua, "pair-qr"), (.darkAqua, "pair-qr-dark")])
    func `the qr step renders`(appearance: NSAppearance.Name, name: String) throws {
        try Self.render(Self.flow(.init()), named: name, appearance: appearance)
    }

    @Test
    func `the not found step renders`() async throws {
        let flow: PairFlow = Self.flow(.init())
        await flow.start().value

        try Self.render(flow, named: "pair-not-found")
    }

    @Test
    func `the code step renders with adb's error under the fields`() async throws {
        let adb: FakeWifiAdb = .init(.init(failingCall: "pair", failure: .failed(line: "Failed: Wrong password or connection was dropped")))
        let flow: PairFlow = Self.flow(adb)
        flow.usePairingCode()
        flow.pairingAddress = "192.168.4.29:37045"
        flow.pairingCode = "000000"
        await flow.submitPairingCode().value

        try Self.render(flow, named: "pair-code-error")
    }

    @Test
    func `the connecting step renders`() async throws {
        let adb: FakeWifiAdb = .init(.init(services: [Self.pairingService]))
        let flow: PairFlow = Self.flow(adb, clock: .init(blocking: true))
        flow.start()
        while flow.state != .connecting { try await Task.sleep(for: .milliseconds(5)) }

        try Self.render(flow, named: "pair-connecting")
        flow.cancel()
    }

    @Test
    func `the manual connect step renders with adb's error under the field`() async throws {
        let adb: FakeWifiAdb = .init(.init(services: [Self.pairingService]))
        let flow: PairFlow = Self.flow(adb)
        await flow.start().value
        adb.update {
            $0.failingCall = "connect"
            $0.failure = .failed(line: "failed to connect to '192.168.4.29:40000': Connection refused")
        }
        flow.manualAddress = "192.168.4.29:40000"
        await flow.submitManualAddress().value

        try Self.render(flow, named: "pair-manual-error")
    }

    @Test(arguments: [(NSAppearance.Name.aqua, "pair-connected"), (.darkAqua, "pair-connected-dark")])
    func `the connected step renders`(appearance: NSAppearance.Name, name: String) async throws {
        let adb: FakeWifiAdb = .init(.init(services: [Self.pairingService], guid: Self.guid, appearances: [.init(call: "pair", device: Self.phone)]))
        let flow: PairFlow = Self.flow(adb)
        await flow.start().value

        try Self.render(flow, named: name, appearance: appearance)
    }
}
