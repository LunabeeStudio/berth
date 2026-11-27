import Synchronization

@testable import BerthBar

final class GatedDeviceClipboard: DeviceClipboard {
    private let text: String?
    private let gate: AsyncStream<Void>
    private let opener: AsyncStream<Void>.Continuation
    private let serials: Mutex<[String]> = .init([])

    var requestedSerials: [String] { serials.withLock { $0 } }

    init(text: String?) {
        self.text = text
        (gate, opener) = AsyncStream.makeStream(of: Void.self)
    }

    func text(serial: String) async throws -> String? {
        serials.withLock { $0.append(serial) }
        for await _ in gate { break }
        return text
    }

    func open() {
        opener.yield()
    }
}
