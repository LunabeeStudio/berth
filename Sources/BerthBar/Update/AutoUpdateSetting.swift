import BerthCore
import Foundation
import Observation

@Observable
@MainActor
final class AutoUpdateSetting {
    let isManagedByHomebrew: Bool
    private(set) var isAvailable: Bool

    @ObservationIgnored private let configURL: URL
    @ObservationIgnored private var stored: Bool

    var isEnabled: Bool {
        get {
            access(keyPath: \.isEnabled)
            return stored && !isManagedByHomebrew
        }
        set {
            withMutation(keyPath: \.isEnabled) {
                if isAvailable {
                    try? Config.setAutoUpdate(newValue, at: configURL)
                }
                read()
            }
        }
    }

    init(configURL: URL = Paths.config, isManagedByHomebrew: Bool = HomebrewInstall.current() != nil) {
        self.configURL = configURL
        self.isManagedByHomebrew = isManagedByHomebrew
        stored = true
        isAvailable = false
        read()
    }

    func refresh() {
        withMutation(keyPath: \.isEnabled) {
            read()
        }
    }

    private func read() {
        if let config = try? Config.load(from: configURL) {
            stored = config.autoUpdate
            isAvailable = !isManagedByHomebrew
        } else {
            stored = true
            isAvailable = false
        }
    }
}
