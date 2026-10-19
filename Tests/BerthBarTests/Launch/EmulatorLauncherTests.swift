import Testing

@testable import BerthBar
@testable import BerthCore

@MainActor
@Suite
struct EmulatorLauncherTests {
    @Test
    func `launch request is a windowed android claim labelled you without ttl`() {
        let owner: Owner = .mock(pid: 7, name: "berth-bar")

        let request: ClaimRequest = EmulatorLauncher.request(model: "Pixel_9", owner: owner)

        #expect(request.model == "Pixel_9")
        #expect(request.resolvedPlatform == .android)
        #expect(request.isWindowed)
        #expect(request.label == "you")
        #expect(request.ttl == nil)
        #expect(request.owner == owner)
    }

    @Test
    func `owner is this process named berth-bar`() {
        #expect(EmulatorLauncher.owner.name == "berth-bar")
        #expect(EmulatorLauncher.owner.startTime != nil)
    }

    @Test
    func `a refused claim sets the error and the next granted one clears it`() async {
        let actions: StubActions = .init(failure: "pool is full")
        let launcher: EmulatorLauncher = .init(actions: actions)

        await launcher.launch(model: "Pixel_9").value
        #expect(launcher.error?.contains("pool is full") == true)

        actions.failure = nil
        await launcher.launch(model: "Pixel_9").value
        #expect(launcher.error == nil)
    }

    @Test
    func `a failed release sets the error`() async {
        let actions: StubActions = .init(failure: "not leased")
        let launcher: EmulatorLauncher = .init(actions: actions)

        await launcher.release(serial: "emulator-5554").value

        #expect(launcher.error?.contains("not leased") == true)
        #expect(actions.releases == ["emulator-5554"])
    }
}
