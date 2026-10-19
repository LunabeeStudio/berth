import Testing

@testable import BerthDaemon

@Suite
struct AndroidLaunchArgumentsTests {
    @Test
    func `headless launch passes -no-window`() {
        let arguments: [String] = AndroidBackend.launchArguments(model: "Pixel", port: 5554, windowed: false, snapshot: "clean")

        #expect(arguments.contains("-no-window"))
    }

    @Test
    func `windowed launch drops only -no-window`() {
        let headless: [String] = AndroidBackend.launchArguments(model: "Pixel", port: 5554, windowed: false, snapshot: "clean")
        let windowed: [String] = AndroidBackend.launchArguments(model: "Pixel", port: 5554, windowed: true, snapshot: "clean")

        #expect(windowed == headless.filter { $0 != "-no-window" })
        #expect(windowed.contains("-read-only"))
        #expect(windowed.contains("-snapshot"))
    }

    @Test
    func `launch without a clean snapshot cold boots`() {
        let arguments: [String] = AndroidBackend.launchArguments(model: "Pixel", port: 5556, windowed: false, snapshot: nil)

        #expect(arguments.suffix(1) == ["-no-snapshot"])
        #expect(arguments.starts(with: ["-avd", "Pixel", "-port", "5556"]))
    }
}
