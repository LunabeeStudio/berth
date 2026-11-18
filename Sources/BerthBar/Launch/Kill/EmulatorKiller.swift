protocol EmulatorKiller: Sendable {
    func kill(serial: String) async throws
}
