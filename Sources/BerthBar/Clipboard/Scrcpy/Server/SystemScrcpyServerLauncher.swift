struct SystemScrcpyServerLauncher: ScrcpyServerLauncher {
    let adb: String

    func launch(adbArguments: [String]) throws -> any ScrcpyServer {
        try ScrcpyServerProcess(adb: adb, arguments: adbArguments)
    }
}
