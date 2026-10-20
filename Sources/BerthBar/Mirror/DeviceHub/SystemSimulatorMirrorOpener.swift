import AppKit
import Foundation

struct SystemSimulatorMirrorOpener: SimulatorMirrorOpener {
    func canOpen(_ url: URL) -> Bool {
        NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }

    func open(_ url: URL) async throws {
        let configuration: NSWorkspace.OpenConfiguration = .init()
        configuration.activates = true
        try await NSWorkspace.shared.open(url, configuration: configuration)
    }
}
