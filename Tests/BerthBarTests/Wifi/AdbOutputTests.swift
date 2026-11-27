import Testing

@testable import BerthBar

@Suite
struct AdbOutputTests {
    @Test
    func `pair success is read from stdout`() {
        #expect(AdbOutput.isPaired(stdout: "Successfully paired to 192.168.4.29:37045 [guid=adb-R3CT312YV5B-AbCdEf]\n"))
    }

    @Test
    func `the guid is read from the pair success line`() {
        let stdout: String = "Successfully paired to 192.168.4.29:37045 [guid=adb-R3CT312YV5B-AbCdEf]\n"

        #expect(AdbOutput.pairedGuid(stdout: stdout) == "adb-R3CT312YV5B-AbCdEf")
    }

    @Test(arguments: ["Successfully paired to 192.168.4.29:37045\n", "Failed: Wrong password\n", ""])
    func `no guid without one on the success line`(stdout: String) {
        #expect(AdbOutput.pairedGuid(stdout: stdout) == nil)
    }

    @Test
    func `a pair failure is not a success`() {
        #expect(!AdbOutput.isPaired(stdout: "Failed: Wrong password or connection was dropped\n"))
        #expect(!AdbOutput.isPaired(stdout: ""))
    }

    @Test(arguments: ["connected to 192.168.4.29:5555\n", "already connected to 192.168.4.29:5555\n"])
    func `connect success is read from stdout`(stdout: String) {
        #expect(AdbOutput.isConnected(stdout: stdout))
    }

    @Test(arguments: [
        "failed to connect to '192.168.4.29:5555': Connection refused\n",
        "cannot connect to 192.168.4.29:5555: Connection refused (61)\n",
        "failed to authenticate to 192.168.4.29:5555\n",
        ""
    ])
    func `a connect failure is not a success even when adb exits 0`(stdout: String) {
        #expect(!AdbOutput.isConnected(stdout: stdout))
    }

    @Test
    func `the error line is the first meaningful line of stderr`() {
        let line: String = AdbOutput.errorLine(
            stdout: "* daemon not running; starting now at tcp:5037\n",
            stderr: "\n  error: device offline  \nsecond\n",
            status: 1
        )

        #expect(line == "error: device offline")
    }

    @Test
    func `the error line falls back to stdout`() {
        let line: String = AdbOutput.errorLine(
            stdout: "* daemon started successfully\nfailed to connect to '10.0.0.2:5555': Connection refused\n",
            stderr: "",
            status: 0
        )

        #expect(line == "failed to connect to '10.0.0.2:5555': Connection refused")
    }

    @Test
    func `the error line names the status when adb printed nothing`() {
        #expect(AdbOutput.errorLine(stdout: "", stderr: "", status: 3) == "adb exited with status 3")
    }

    @Test
    func `an error prefixed line is reported on either stream`() {
        #expect(AdbOutput.reportsError(stdout: "error: no such device '10.0.0.2:5555'\n", stderr: ""))
        #expect(AdbOutput.reportsError(stdout: "", stderr: "error: device offline\n"))
        #expect(!AdbOutput.reportsError(stdout: "restarting in TCP mode port: 5555\n", stderr: ""))
    }
}
