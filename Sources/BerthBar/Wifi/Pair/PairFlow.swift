import BerthCore
import Observation

@Observable
@MainActor
final class PairFlow {
    enum State: Equatable {
        case waitingForQR(PairQR)
        case notFound
        case codeEntry(error: String?)
        case pairing
        case connecting
        case manualConnect(error: String?)
        case connected(PhysicalDevice)
    }

    private struct PairedPhone {
        let host: String
        let guid: String?

        func owns(_ device: PhysicalDevice) -> Bool {
            device.state == .device
                && device.isWifi
                && (device.serial.hasPrefix("\(host):") || guid.map { device.serial.hasPrefix("\($0).") } == true)
        }

        func owns(_ service: MdnsService) -> Bool {
            service.kind == .connect && (guid.map { service.name == $0 } ?? (service.host == host))
        }
    }

    nonisolated static let qrTimeout: Duration = .seconds(120)
    nonisolated static let deviceTimeout: Duration = .seconds(10)
    nonisolated static let pollInterval: Duration = .seconds(1)

    var pairingAddress: String = ""
    var pairingCode: String = ""
    var manualAddress: String = ""
    private(set) var state: State
    private let adb: any WifiAdb
    private let clock: any PairClock
    private let credentials: @Sendable () -> PairQR
    private var task: Task<Void, Never>?

    init(
        adb: any WifiAdb = SdkWifiAdb(),
        clock: any PairClock = SystemPairClock(),
        credentials: @escaping @Sendable () -> PairQR = PairQR.random
    ) {
        self.adb = adb
        self.clock = clock
        self.credentials = credentials
        state = .waitingForQR(credentials())
    }

    @discardableResult
    func start() -> Task<Void, Never> {
        if let task { return task }
        guard case let .waitingForQR(qr) = state else { return Task {} }
        return run { await self.waitForPhone(qr) }
    }

    @discardableResult
    func retry() -> Task<Void, Never> {
        let qr: PairQR = credentials()
        state = .waitingForQR(qr)
        return run { await self.waitForPhone(qr) }
    }

    func usePairingCode() {
        cancel()
        state = .codeEntry(error: nil)
    }

    @discardableResult
    func submitPairingCode() -> Task<Void, Never> {
        let address: String = pairingAddress.trimmingCharacters(in: .whitespaces)
        let code: String = pairingCode.trimmingCharacters(in: .whitespaces)
        return run { await self.pair(address: address, code: code) }
    }

    @discardableResult
    func submitManualAddress() -> Task<Void, Never> {
        let address: String = manualAddress.trimmingCharacters(in: .whitespaces)
        return run { await self.connectManually(to: address) }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private func run(_ body: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        task?.cancel()
        let started: Task<Void, Never> = Task { await body() }
        task = started
        return started
    }

    private func waitForPhone(_ qr: PairQR) async {
        let deadline: Duration = clock.now() + Self.qrTimeout
        while true {
            let services: [MdnsService] = (try? await adb.mdnsServices()) ?? []
            guard !Task.isCancelled else { return }
            if let service = services.first(where: { $0.kind == .pairing && $0.name == qr.name }) {
                await pair(address: service.address, code: qr.password)
                return
            }
            guard clock.now() < deadline else { break }
            guard await pause() else { return }
        }
        state = .notFound
    }

    private func pair(address: String, code: String) async {
        pairingAddress = address
        state = .pairing
        let guid: String?
        do {
            guid = try await adb.pair(address: address, code: code)
        } catch {
            guard !Task.isCancelled else { return }
            state = .codeEntry(error: "\(error)")
            return
        }
        guard !Task.isCancelled else { return }
        await connectAfterPair(PairedPhone(host: MdnsService.host(ofAddress: address), guid: guid))
    }

    private func connectAfterPair(_ phone: PairedPhone) async {
        state = .connecting
        if let device = await awaitDevice(of: phone) { return state = .connected(device) }
        guard !Task.isCancelled else { return }
        if
            let service = ((try? await adb.mdnsServices()) ?? []).first(where: phone.owns),
            (try? await adb.connect(address: service.address)) != nil,
            let device = await awaitDevice(of: phone)
        {
            return state = .connected(device)
        }
        guard !Task.isCancelled else { return }
        state = .manualConnect(error: nil)
    }

    private func connectManually(to address: String) async {
        state = .connecting
        do {
            try await adb.connect(address: address)
        } catch {
            guard !Task.isCancelled else { return }
            state = .manualConnect(error: "\(error)")
            return
        }
        let phone: PairedPhone = .init(host: MdnsService.host(ofAddress: address), guid: nil)
        if let device = await awaitDevice(of: phone) { return state = .connected(device) }
        guard !Task.isCancelled else { return }
        state = .manualConnect(error: "\(address) is not in the adb device list")
    }

    private func awaitDevice(of phone: PairedPhone) async -> PhysicalDevice? {
        let deadline: Duration = clock.now() + Self.deviceTimeout
        while true {
            let devices: [PhysicalDevice] = (try? await adb.devices()) ?? []
            if let device = devices.first(where: phone.owns) { return device }
            guard clock.now() < deadline, await pause() else { return nil }
        }
    }

    private func pause() async -> Bool {
        do {
            try await clock.sleep(for: Self.pollInterval)
        } catch {
            return false
        }
        return !Task.isCancelled
    }
}
