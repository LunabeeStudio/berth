import Foundation
import Testing

@testable import berth
@testable import BerthCore

@Suite
struct StatusRendererTests {
    private static let now: Date = .init(timeIntervalSince1970: 1_800_000_000)

    private func lines(manual: Bool) -> [String] {
        let lease: Lease = .mock(expiresAt: manual ? .distantFuture : Self.now.addingTimeInterval(3000), manual: manual)
        let slot: Slot = .mock(state: .leased, lease: lease, windowed: true)
        let renderer: StatusRenderer = .init(snapshot: .mock(slots: [slot], generatedAt: Self.now), now: Self.now, colors: false)
        return renderer.lines(selected: nil)
    }

    @Test
    func `manual lease shows a dash as remaining time`() throws {
        let line: String = try #require(lines(manual: true).first { $0.hasPrefix("  emulator-5554") })

        #expect(line.hasSuffix("—      "))
    }

    @Test
    func `agent lease on a windowed slot shows its remaining time`() throws {
        let line: String = try #require(lines(manual: false).first { $0.hasPrefix("  emulator-5554") })

        #expect(!line.hasSuffix("—      "))
    }
}
