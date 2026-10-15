import Testing

@testable import berth

@Suite
struct SimpleCommandTests {
    @Test
    func `reads the command name by basename`() {
        let command: SimpleCommand = .init(words: ["/opt/sdk/emulator/emulator", "-avd", "X"])
        #expect(command.name == "emulator")
        #expect(command.arguments == ["-avd", "X"])
    }

    @Test
    func `collects leading assignments`() {
        let command: SimpleCommand = .init(words: ["A=1", "B=", "adb", "devices"])
        #expect(command.assignments == ["A": "1", "B": ""])
        #expect(command.name == "adb")
    }

    @Test(arguments: [
        ["sudo", "adb", "devices"],
        ["env", "-i", "A=1", "adb", "devices"],
        ["timeout", "30", "adb", "devices"],
        ["rtk", "proxy", "adb", "devices"],
        ["nohup", "time", "adb", "devices"],
    ])
    func `skips wrappers`(words: [String]) {
        #expect(SimpleCommand(words: words).name == "adb")
    }

    @Test
    func `assignment-only segment has no command name`() {
        #expect(SimpleCommand(words: ["ANDROID_SERIAL=x"]).name == nil)
    }

    @Test
    func `option-like words are not assignments`() {
        #expect(SimpleCommand.assignment("--x=1") == nil)
        #expect(SimpleCommand.assignment("=1") == nil)
    }
}
