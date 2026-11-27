protocol ScrcpyServerLauncher: Sendable {
    func launch(adbArguments: [String]) throws -> any ScrcpyServer
}
