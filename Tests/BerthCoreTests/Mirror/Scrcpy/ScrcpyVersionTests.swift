import Testing

@testable import BerthCore

@Suite
struct ScrcpyVersionTests {
    @Test
    func `reads the version from the first line`() {
        let output: String = "scrcpy 5.0.1 <https://github.com/Genymobile/scrcpy>\n\nDependencies (compiled / linked):\n"

        #expect(ScrcpyVersion.parse(versionOutput: output) == "5.0.1")
    }

    @Test
    func `reads a bare version line`() {
        #expect(ScrcpyVersion.parse(versionOutput: "scrcpy 3.3\n") == "3.3")
    }

    @Test
    func `rejects output that is not a scrcpy version`() {
        #expect(ScrcpyVersion.parse(versionOutput: "") == nil)
        #expect(ScrcpyVersion.parse(versionOutput: "scrcpy\n") == nil)
        #expect(ScrcpyVersion.parse(versionOutput: "zsh: command not found: scrcpy\n") == nil)
    }
}
