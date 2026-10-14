import BerthCore
@testable import BerthDaemon
import Foundation
import Synchronization
import Testing

struct Timeout: Error {}

func eventually(_ condition: @Sendable () async -> Bool) async throws {
    for _ in 0..<200 {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw Timeout()
}
