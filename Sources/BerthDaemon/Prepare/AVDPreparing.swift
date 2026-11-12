public protocol AVDPreparing: Sendable {
    func knownAVDs() async -> [String]
    func liveSerials() async -> Set<String>
    func avdName(serial: String) async -> String?
    /// Boots `avd` as `serial` and saves its clean snapshot, then shuts the emulator down; cancelling shuts it down too.
    func prepare(avd: String, serial: String, settle: Int, progress: @Sendable (String) -> Void) async throws
}
