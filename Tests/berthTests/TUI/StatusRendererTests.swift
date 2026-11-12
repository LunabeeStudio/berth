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

    @Test
    func `device column shows the numbered name`() throws {
        let slot: Slot = .mock(model: "Pixel_10_Pro", instance: 2)
        let renderer: StatusRenderer = .init(snapshot: .mock(slots: [slot], generatedAt: Self.now), now: Self.now, colors: false)

        let line: String = try #require(renderer.lines(selected: nil).first { $0.hasPrefix("  emulator-5554") })

        #expect(line.contains("Pixel_10_Pro - 2 "))
    }

    @Test
    func `a long name is cut in the model part and keeps its number`() throws {
        let slot: Slot = .mock(model: "Medium_Phone_API_36", instance: 2)
        let renderer: StatusRenderer = .init(snapshot: .mock(slots: [slot], generatedAt: Self.now), now: Self.now, colors: false)

        let line: String = try #require(renderer.lines(selected: nil).first { $0.hasPrefix("  emulator-5554") })

        #expect(line.contains("Medium_Phone_… - 2 "))
    }

    private func headerLines(restartedAgo: TimeInterval?) -> [String] {
        let snapshot: StateSnapshot = .mock(adbRestartedAt: restartedAgo.map { Self.now.addingTimeInterval(-$0) })
        return StatusRenderer(snapshot: snapshot, now: Self.now, colors: false).lines(selected: nil)
    }

    @Test
    func `a recent adb restart shows the notice under the header`() {
        let lines: [String] = headerLines(restartedAgo: 12)

        #expect(lines[1] == "adb unstable: server restarted 12 s ago; devices reconnect on their own, keep your lease")
    }

    @Test
    func `no notice without a recent adb restart`() {
        #expect(!headerLines(restartedAgo: nil).contains { $0.hasPrefix("adb unstable") })
        #expect(!headerLines(restartedAgo: 60).contains { $0.hasPrefix("adb unstable") })
    }
}
