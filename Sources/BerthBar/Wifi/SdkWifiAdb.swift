import BerthCore

struct SdkWifiAdb: WifiAdb {
    private let adb: String

    init(adb: String = Config.defaultADBPath()) {
        self.adb = adb
    }

    func mdnsServices() async throws -> [MdnsService] {
        let result: ShellResult = try await run("mdns", ["mdns", "services"])
        return MdnsService.parse(adbMdnsServices: result.stdout)
    }

    func pair(address: String, code: String) async throws -> String? {
        let result: ShellResult = try await run("pair", ["pair", address, code])
        guard AdbOutput.isPaired(stdout: result.stdout) else { throw failure(result) }
        return AdbOutput.pairedGuid(stdout: result.stdout)
    }

    func connect(address: String) async throws {
        let result: ShellResult = try await run("connect", ["connect", address])
        guard AdbOutput.isConnected(stdout: result.stdout) else { throw failure(result) }
    }

    func disconnect(serial: String) async throws {
        let result: ShellResult = try await run("disconnect", ["disconnect", serial])
        if AdbOutput.reportsNoSuchDevice(stdout: result.stdout, stderr: result.stderr) { return }
        try expectSuccess(result)
    }

    func tcpip(serial: String, port: Int) async throws {
        try expectSuccess(await run("tcpip", ["-s", serial, "tcpip", String(port)]))
    }

    func wifiAddress(serial: String) async throws -> String? {
        let result: ShellResult = try await run("shell", ["-s", serial, "shell", "ip", "-f", "inet", "addr", "show", "wlan0"])
        if result.succeeded { return WifiAddress.parse(ipAddr: result.stdout) }
        if (result.stdout + result.stderr).contains("does not exist") { return nil }
        throw failure(result)
    }

    func devices() async throws -> [PhysicalDevice] {
        let result: ShellResult = try await run("devices", ["devices", "-l"])
        guard result.succeeded else { throw failure(result) }
        return DeviceListing.parse(adbDevices: result.stdout).devices
    }

    private func run(_ command: String, _ arguments: [String]) async throws -> ShellResult {
        let result: ShellResult = try await Shell.run(adb, arguments, timeout: .seconds(15))
        if result.timedOut { throw WifiAdbError.timedOut(command: command) }
        return result
    }

    private func expectSuccess(_ result: ShellResult) throws {
        guard result.succeeded, !AdbOutput.reportsError(stdout: result.stdout, stderr: result.stderr) else { throw failure(result) }
    }

    private func failure(_ result: ShellResult) -> WifiAdbError {
        .failed(line: AdbOutput.errorLine(stdout: result.stdout, stderr: result.stderr, status: result.status))
    }
}
