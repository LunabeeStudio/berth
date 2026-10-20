import Testing

@testable import BerthCore

@Suite
struct ScrcpyArgumentsTests {
    @Test
    func `control mirror selects the serial, mutes audio and titles the window`() {
        let arguments: [String] = ScrcpyArguments.make(serial: "emulator-5554", model: "Pixel_9", mode: .control)

        #expect(arguments == ["-s", "emulator-5554", "--no-audio", "--window-title", "emulator-5554 Pixel_9"])
    }

    @Test
    func `view only mirror adds no-control and the title suffix`() {
        let arguments: [String] = ScrcpyArguments.make(serial: "emulator-5554", model: "Pixel_9", mode: .viewOnly)

        #expect(arguments.starts(with: ["-s", "emulator-5554", "--no-audio"]))
        #expect(arguments.contains("--no-control"))
        #expect(arguments.contains("emulator-5554 Pixel_9 (view only)"))
    }
}
