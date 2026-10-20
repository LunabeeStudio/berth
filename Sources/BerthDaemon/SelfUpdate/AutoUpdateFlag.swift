import BerthCore
import Foundation
import Synchronization

final class AutoUpdateFlag: Sendable {
    private let configURL: URL
    private let log: @Sendable (String) -> Void
    private let lastGood: Mutex<Bool>

    init(configURL: URL = Paths.config, initial: Bool, log: @escaping @Sendable (String) -> Void = { Log.info($0) }) {
        self.configURL = configURL
        self.log = log
        lastGood = .init(initial)
    }

    func isEnabled() -> Bool {
        do {
            if let config = try Config.load(from: configURL) {
                lastGood.withLock { $0 = config.autoUpdate }
            }
        } catch {
            log("auto update: config unreadable, keeping last value: \(error.localizedDescription)")
        }
        return lastGood.withLock { $0 }
    }
}
