import Foundation
import Testing

@testable import BerthBar
@testable import BerthCore

@MainActor
@Suite
struct MirrorControllerTests {
    private static let scrcpyDirectory: String = {
        let directory: URL = FileManager.default.temporaryDirectory.appending(path: "berth-fake-scrcpy", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: directory.appending(path: "scrcpy").path, contents: Data(), attributes: [.posixPermissions: 0o755])
        return directory.path
    }()

    private let launcher: FakeMirrorLauncher = .init()
    private let opener: FakeSimulatorMirrorOpener = .init()
    private let logs: URL = .init(fileURLWithPath: "/tmp/berth-logs")

    @Test
    func `a free slot opens a controlled mirror`() throws {
        let controller: MirrorController = makeController()

        controller.open(.mock(serial: "emulator-5554", model: "Pixel_9", state: .free), platform: .android)

        let launch: FakeMirrorLauncher.Launch = try #require(launcher.launches.first)
        #expect(launch.executable == Self.scrcpyDirectory + "/scrcpy")
        #expect(launch.arguments == ScrcpyArguments.make(serial: "emulator-5554", model: "Pixel_9", mode: .control))
        #expect(launch.log == logs.appending(path: "mirror-emulator-5554.log"))
    }

    @Test
    func `a leased slot opens a view only mirror`() throws {
        let controller: MirrorController = makeController()

        controller.open(.mock(serial: "emulator-5554", model: "Pixel_9", state: .leased), platform: .android)

        let launch: FakeMirrorLauncher.Launch = try #require(launcher.launches.first)
        #expect(launch.arguments.contains("--no-control"))
    }

    @Test
    func `a second click brings the open mirror to front without a second process`() {
        var activated: [Int32] = []
        let controller: MirrorController = makeController { activated.append($0) }
        let slot: Slot = .mock(serial: "emulator-5554")

        controller.open(slot, platform: .android)
        controller.open(slot, platform: .android)

        #expect(launcher.launches.count == 1)
        #expect(activated == [100])
    }

    @Test
    func `two serials open two mirrors`() {
        let controller: MirrorController = makeController()

        controller.open(.mock(serial: "emulator-5554"), platform: .android)
        controller.open(.mock(serial: "emulator-5556"), platform: .android)

        #expect(launcher.launches.count == 2)
    }

    @Test
    func `a controlled mirror restarts view only when its slot is leased`() throws {
        let controller: MirrorController = makeController()
        controller.open(.mock(serial: "emulator-5554", model: "Pixel_9", state: .free), platform: .android)

        controller.apply(.mock(slots: [.mock(serial: "emulator-5554", model: "Pixel_9", state: .leased)]))

        #expect(launcher.launches.count == 2)
        #expect(launcher.launches[0].process.terminated)
        #expect(launcher.launches[1].arguments.contains("--no-control"))
        #expect(launcher.launches[1].arguments.contains("emulator-5554 Pixel_9 (view only)"))
    }

    @Test
    func `the controller's own stop on the switch shows no caption`() {
        let controller: MirrorController = makeController()
        controller.open(.mock(serial: "emulator-5554", state: .free), platform: .android)

        controller.apply(.mock(slots: [.mock(serial: "emulator-5554", state: .leased)]))
        launcher.launches[0].onExit(15)

        #expect(controller.caption == nil)
        #expect(!launcher.launches[1].process.terminated)
    }

    @Test
    func `a view only mirror is not restarted`() {
        let controller: MirrorController = makeController()
        controller.open(.mock(serial: "emulator-5554", state: .leased), platform: .android)

        controller.apply(.mock(slots: [.mock(serial: "emulator-5554", state: .leased)]))
        controller.apply(.mock(slots: [.mock(serial: "emulator-5554", state: .free)]))
        controller.apply(.mock(slots: [.mock(serial: "emulator-5554", state: .leased)]))

        #expect(launcher.launches.count == 1)
    }

    @Test
    func `a controlled mirror on a still free slot is left alone`() {
        let controller: MirrorController = makeController()
        controller.open(.mock(serial: "emulator-5554", state: .free), platform: .android)

        controller.apply(.mock(slots: [.mock(serial: "emulator-5554", state: .free)]))

        #expect(launcher.launches.count == 1)
    }

    @Test
    func `an exited mirror is forgotten so the next click opens a new one`() {
        let controller: MirrorController = makeController()
        let slot: Slot = .mock(serial: "emulator-5554")
        controller.open(slot, platform: .android)

        launcher.launches[0].onExit(2)
        controller.open(slot, platform: .android)

        #expect(launcher.launches.count == 2)
    }

    @Test(arguments: [Int32(0), 2])
    func `a normal exit shows no caption`(code: Int32) {
        let controller: MirrorController = makeController()
        controller.open(.mock(serial: "emulator-5554"), platform: .android)

        launcher.launches[0].onExit(code)

        #expect(controller.caption == nil)
    }

    @Test
    func `another exit code shows the failure caption with the log path`() {
        let controller: MirrorController = makeController()
        controller.open(.mock(serial: "emulator-5554"), platform: .android)

        launcher.launches[0].onExit(1)

        #expect(controller.caption == "mirror emulator-5554 failed, see \(logs.appending(path: "mirror-emulator-5554.log").path)")
    }

    @Test
    func `a launch that throws shows the error in the caption`() {
        launcher.failure = true
        let controller: MirrorController = makeController()

        controller.open(.mock(serial: "emulator-5554"), platform: .android)

        #expect(controller.caption?.hasPrefix("mirror emulator-5554 failed: ") == true)
    }

    @Test
    func `scrcpy not found launches nothing and shows the install caption`() {
        let controller: MirrorController = makeController(scrcpy: false)

        controller.open(.mock(serial: "emulator-5554"), platform: .android)

        #expect(launcher.launches.isEmpty)
        #expect(controller.caption == "scrcpy not found: brew install scrcpy")
    }

    @Test
    func `the next click clears the caption`() {
        let controller: MirrorController = makeController()
        controller.open(.mock(serial: "emulator-5554"), platform: .android)
        launcher.launches[0].onExit(1)

        controller.open(.mock(serial: "emulator-5554"), platform: .android)

        #expect(controller.caption == nil)
    }

    @Test
    func `stopAll stops every mirror it started and shows no caption`() {
        let controller: MirrorController = makeController()
        controller.open(.mock(serial: "emulator-5554"), platform: .android)
        controller.open(.mock(serial: "emulator-5556"), platform: .android)

        controller.stopAll()
        launcher.launches.forEach { $0.onExit(15) }

        #expect(launcher.launches.allSatisfy { $0.process.terminated })
        #expect(controller.caption == nil)
    }

    @Test(arguments: [SlotState.free, .leased])
    func `an ios slot opens the DeviceHub url and never launches scrcpy`(state: SlotState) async {
        let controller: MirrorController = makeController()

        controller.open(.mock(serial: "UDID-1", model: "iPhone 16", state: state), platform: .ios)
        await controller.pendingSimulatorOpen?.value

        #expect(opener.opened.map(\.absoluteString) == ["devices://device/open?id=UDID-1"])
        #expect(launcher.launches.isEmpty)
        #expect(controller.caption == nil)
    }

    @Test
    func `no app for the devices scheme opens nothing and shows the Xcode caption`() async {
        opener.handlesScheme = false
        let controller: MirrorController = makeController()

        controller.open(.mock(serial: "UDID-1"), platform: .ios)
        await controller.pendingSimulatorOpen?.value

        #expect(opener.opened.isEmpty)
        #expect(controller.caption == "DeviceHub not found: needs Xcode 27")
    }

    @Test
    func `an open that throws shows the error in the caption`() async {
        opener.failure = CocoaError(.fileNoSuchFile)
        let controller: MirrorController = makeController()

        controller.open(.mock(serial: "UDID-1"), platform: .ios)
        await controller.pendingSimulatorOpen?.value

        #expect(controller.caption?.hasPrefix("mirror UDID-1 failed: ") == true)
    }

    @Test
    func `the next ios click clears the caption`() async {
        opener.handlesScheme = false
        let controller: MirrorController = makeController()
        controller.open(.mock(serial: "UDID-1"), platform: .ios)
        opener.handlesScheme = true

        controller.open(.mock(serial: "UDID-1"), platform: .ios)
        await controller.pendingSimulatorOpen?.value

        #expect(controller.caption == nil)
    }

    @Test
    func `apply and stopAll leave ios slots alone`() async {
        let controller: MirrorController = makeController()
        controller.open(.mock(serial: "UDID-1", state: .free), platform: .ios)
        await controller.pendingSimulatorOpen?.value

        controller.apply(.mock(slots: [.mock(serial: "UDID-1", state: .leased)]))
        controller.stopAll()

        #expect(launcher.launches.isEmpty)
        #expect(opener.opened.count == 1)
        #expect(controller.caption == nil)
    }

    private func makeController(scrcpy: Bool = true, activate: @escaping @MainActor (Int32) -> Void = { _ in }) -> MirrorController {
        let locator: ScrcpyLocator = scrcpy ? .init(environment: [:], fallbackDirectories: [Self.scrcpyDirectory]) : .init(environment: [:], fallbackDirectories: [])
        return .init(launcher: launcher, locator: locator, logs: logs, activate: activate, simulatorOpener: opener)
    }
}
