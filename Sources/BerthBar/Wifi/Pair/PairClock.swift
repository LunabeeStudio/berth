protocol PairClock: Sendable {
    func now() -> Duration
    func sleep(for duration: Duration) async throws
}
