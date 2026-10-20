import AppKit
import Foundation

public struct SystemSimulatorMirrorOpener: SimulatorMirrorOpener {
    public init() {}

    public func canOpen(_ url: URL) -> Bool {
        NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }

    public func open(_ url: URL) async throws {
        let configuration: NSWorkspace.OpenConfiguration = .init()
        configuration.activates = true
        try await NSWorkspace.shared.open(url, configuration: configuration)
    }
}
