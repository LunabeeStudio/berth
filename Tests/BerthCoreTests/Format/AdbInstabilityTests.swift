import Foundation
import Testing

@testable import BerthCore

@Suite
struct AdbInstabilityTests {
    private static let restartedAt: Date = .init(timeIntervalSince1970: 1000)

    private func notice(after seconds: TimeInterval) -> String? {
        AdbInstability.notice(restartedAt: Self.restartedAt, now: Self.restartedAt.addingTimeInterval(seconds))
    }

    @Test
    func `notice carries the elapsed seconds`() {
        #expect(notice(after: 7.9) == "adb unstable: server restarted 7 s ago; devices reconnect on their own, keep your lease")
    }

    @Test
    func `window is inclusive of 59 s and exclusive of 60 s`() {
        #expect(notice(after: 59) != nil)
        #expect(notice(after: 60) == nil)
    }

    @Test
    func `no restart means no notice`() {
        #expect(AdbInstability.notice(restartedAt: nil, now: Self.restartedAt) == nil)
    }
}
