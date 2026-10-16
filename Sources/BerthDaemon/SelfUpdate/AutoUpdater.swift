import BerthCore
import Foundation

struct AutoUpdater: Sendable {
    let source: any UpdateSource
    let delay: Duration
    let interval: Duration
    let log: @Sendable (String) -> Void
    private let isEnabled: Bool

    init(
        source: any UpdateSource,
        autoUpdate: Bool,
        currentVersion: String = BerthVersion.current,
        delay: Duration = .seconds(60),
        interval: Duration = .seconds(24 * 3600),
        log: @escaping @Sendable (String) -> Void = { Log.info($0) }
    ) {
        self.source = source
        self.delay = delay
        self.interval = interval
        self.log = log
        isEnabled = autoUpdate && SemanticVersion(currentVersion) != nil
    }

    func run() async {
        guard isEnabled else { return }
        try? await Task.sleep(for: delay)
        while !Task.isCancelled {
            await checkOnce()
            try? await Task.sleep(for: interval)
        }
    }

    func checkOnce() async {
        guard isEnabled else { return }
        do {
            guard case let .available(current, latest, release) = try await source.check() else { return }
            try await source.install(release)
            log("auto update: installed \(current) → \(latest)")
        } catch {
            log("auto update failed: \(error.localizedDescription)")
        }
    }
}
