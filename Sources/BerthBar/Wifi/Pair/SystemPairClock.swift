struct SystemPairClock: PairClock {
    private let origin: ContinuousClock.Instant = .now

    func now() -> Duration {
        origin.duration(to: .now)
    }

    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
