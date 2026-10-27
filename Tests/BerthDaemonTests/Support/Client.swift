import BerthCore
@testable import BerthDaemon
import Foundation
import Synchronization
import Testing

final class Client: Sendable {
    let conn = UUID()
    let sink: AsyncStream<Event>.Continuation
    private let log = EventLog()

    init() {
        let (stream, sink) = AsyncStream.makeStream(of: Event.self)
        self.sink = sink
        let log = log
        Task { for await event in stream { log.events.withLock { $0.append(event) } } }
    }

    var grant: Grant? {
        log.events.withLock { $0.compactMap { if case let .granted(grant) = $0 { grant } else { nil } }.first }
    }

    var failure: String? {
        log.events.withLock { $0.compactMap { if case let .failure(message) = $0 { message } else { nil } }.first }
    }

    var notices: [String] {
        log.events.withLock { $0.compactMap { if case let .ok(notice) = $0 { notice } else { nil } } }
    }

    var lastPosition: Int? {
        log.events.withLock { $0.compactMap { if case let .queued(position) = $0 { position } else { nil } }.last }
    }
}
