import Foundation
import Testing

@testable import BerthCore

@Suite
struct DaemonClientPrepareTests {
    @Test
    func `progress lines are delivered in order and ok ends the prepare`() throws {
        var lines: [String] = []
        let events: [Event] = [.progress("booting"), .state(.mock()), .progress("settling"), .ok("saved")]

        let results: [String?] = try events.map { try DaemonClient.prepareOutcome(of: $0) { lines.append($0) } }

        #expect(lines == ["booting", "settling"])
        #expect(results == [nil, nil, nil, "saved"])
    }

    @Test
    func `a failure event is thrown with its message`() {
        #expect(throws: ClientError.self) {
            try DaemonClient.prepareOutcome(of: .failure("boom")) { _ in }
        }
    }
}
