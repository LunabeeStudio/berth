import Foundation

@testable import BerthBar

@MainActor
final class FakeSimulatorMirrorOpener: SimulatorMirrorOpener {
    private(set) var opened: [URL] = []
    var handlesScheme: Bool = true
    var failure: (any Error)?

    func canOpen(_ url: URL) -> Bool {
        handlesScheme
    }

    func open(_ url: URL) async throws {
        if let failure { throw failure }
        opened.append(url)
    }
}
