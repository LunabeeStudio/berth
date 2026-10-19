import Foundation
import Testing

@testable import berth
@testable import BerthCore

@Suite
struct StatusRendererTests {
    private static let now: Date = .init(timeIntervalSince1970: 1_800_000_000)

    private func lines(windowed: Bool) -> [String] {
        let lease: Lease = .mock(expiresAt: windowed ? .distantFuture : Self.now.addingTimeInterval(3000))
        let slot: Slot = .mock(state: .leased, lease: lease, windowed: windowed)
        let renderer: StatusRenderer = .init(snapshot: .mock(slots: [slot], generatedAt: Self.now), now: Self.now, colors: false)
        return renderer.lines(selected: nil)
    }

    @Test
    func `windowed lease shows a dash as remaining time`() throws {
        let line: String = try #require(lines(windowed: true).first { $0.hasPrefix("  emulator-5554") })

        #expect(line.hasSuffix("—      "))
    }

    @Test
    func `agent lease shows its remaining time`() throws {
        let line: String = try #require(lines(windowed: false).first { $0.hasPrefix("  emulator-5554") })

        #expect(!line.hasSuffix("—      "))
    }
}
