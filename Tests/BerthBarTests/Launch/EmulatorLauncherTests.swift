import Testing

@testable import BerthBar
@testable import BerthCore

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
}
