import Foundation

@MainActor
public protocol SimulatorMirrorOpener {
    func canOpen(_ url: URL) -> Bool
    func open(_ url: URL) async throws
}
