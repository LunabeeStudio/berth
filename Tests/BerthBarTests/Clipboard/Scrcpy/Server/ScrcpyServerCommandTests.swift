import Testing

@testable import BerthBar

@Suite
struct ScrcpyServerCommandTests {
    @Test
    func `starts the server through app_process with a control only, side effect free option set`() {
        let command: ScrcpyServerCommand = .init(version: "5.0.1", scid: 0x1234abc)

        #expect(
            command.adbArguments(serial: "R3CT312YV5B") == [
                "-s", "R3CT312YV5B", "shell",
                "CLASSPATH=/data/local/tmp/berth-scrcpy-server.jar", "app_process", "/", "com.genymobile.scrcpy.Server", "5.0.1",
                "scid=01234abc",
                "log_level=warn",
                "tunnel_forward=true",
                "video=false",
                "audio=false",
                "control=true",
                "send_device_meta=false",
                "power_on=false",
                "cleanup=false",
                "clipboard_autosync=false",
            ]
        )
    }

    @Test
    func `forwards to the abstract socket named after the scid in 8 hex digits`() {
        #expect(ScrcpyServerCommand(version: "5.0.1", scid: 255).socketName == "localabstract:scrcpy_000000ff")
        #expect(ScrcpyServerCommand(version: "5.0.1", scid: 0x7fff_ffff).socketName == "localabstract:scrcpy_7fffffff")
    }

    @Test
    func `kills only the server of its own scid, with a pattern that does not match the killing shell`() throws {
        let command: ScrcpyServerCommand = .init(version: "5.0.1", scid: 0x1234abc)

        let arguments: [String] = command.killArguments(serial: "R3CT312YV5B")

        #expect(arguments == ["-s", "R3CT312YV5B", "shell", "pkill -f 'com.genymobile.[s]crcpy.Server .*scid=01234abc'"])
        let pattern: String = "com.genymobile.[s]crcpy.Server .*scid=01234abc"
        #expect(try Regex(pattern).firstMatch(in: "app_process / com.genymobile.scrcpy.Server 5.0.1 scid=01234abc log_level=warn") != nil)
        #expect(try Regex(pattern).firstMatch(in: "sh -c pkill -f '\(pattern)'") == nil)
        #expect(try Regex(pattern).firstMatch(in: "app_process / com.genymobile.scrcpy.Server 5.0.1 scid=0ffffff1") == nil)
    }

    @Test
    func `finds its forwards by socket name among the forwards of all devices`() {
        let command: ScrcpyServerCommand = .init(version: "5.0.1", scid: 255)
        let listing: String = """
            R3CT312YV5B tcp:50001 localabstract:scrcpy_000000ff
            R3CT312YV5B tcp:50002 localabstract:scrcpy_0000ee00
            emulator-5554 tcp:50003 localabstract:scrcpy_000000ff
            R3CT312YV5B tcp:8000 tcp:8000

            """

        #expect(command.forwardEndpoints(in: listing, serial: "R3CT312YV5B") == ["tcp:50001"])
        #expect(command.forwardEndpoints(in: "", serial: "R3CT312YV5B").isEmpty)
    }

    @Test
    func `random scids fit in 31 bits`() {
        for _ in 0 ..< 200 {
            let scid: Int = ScrcpyServerCommand.randomScid()
            #expect(scid >= 0 && scid < 1 << 31)
        }
    }
}
