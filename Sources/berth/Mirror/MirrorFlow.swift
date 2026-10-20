import BerthCore
import Foundation

@MainActor
struct MirrorFlow {
    private let locator: ScrcpyLocator
    private let launcher: any AndroidMirrorLauncher
    private let opener: any SimulatorMirrorOpener
    private let adb: String
    private let logs: URL

    init(
        locator: ScrcpyLocator = .init(),
        launcher: any AndroidMirrorLauncher = SpawnMirrorLauncher(),
        opener: any SimulatorMirrorOpener = SystemSimulatorMirrorOpener(),
        adb: String = ((try? Config.load()) ?? .init()).adbPath,
        logs: URL = Paths.logs
    ) {
        self.locator = locator
        self.launcher = launcher
        self.opener = opener
        self.adb = adb
        self.logs = logs
    }

    func open(_ target: MirrorTarget) async throws {
        switch target {
        case let .android(serial, model): try openAndroid(serial: serial, model: model)
        case let .ios(udid): try await openSimulator(udid: udid)
        }
    }

    private func openAndroid(serial: String, model: String) throws {
        guard let scrcpy: String = locator.locate() else { throw MirrorError.scrcpyNotFound }
        let environment: [String: String] = ProcessInfo.processInfo.environment.merging(["ADB": adb]) { _, new in new }
        do {
            try launcher.launch(
                executable: scrcpy,
                arguments: ScrcpyArguments.make(serial: serial, model: model, mode: .control),
                log: logs.appending(path: "mirror-\(serial).log"),
                environment: environment
            )
        } catch {
            throw MirrorError.failed(serial: serial, reason: "\(error)")
        }
    }

    private func openSimulator(udid: String) async throws {
        guard let url: URL = DeviceHubURL.open(udid: udid), opener.canOpen(url) else { throw MirrorError.deviceHubNotFound }
        do {
            try await opener.open(url)
        } catch {
            throw MirrorError.failed(serial: udid, reason: "\(error)")
        }
    }
}
