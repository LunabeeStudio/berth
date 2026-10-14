import Foundation

public enum DaemonWatch {
    public static func updates(autoSpawn: Bool) -> AsyncStream<WatchUpdate> {
        let (stream, sink): (AsyncStream<WatchUpdate>, AsyncStream<WatchUpdate>.Continuation) = AsyncStream.makeStream(of: WatchUpdate.self)
        let watcher: Task<Void, Never> = Task {
            while !Task.isCancelled {
                do {
                    try await DaemonClient.withSession(autoSpawn: autoSpawn) { session in
                        try await session.send(.watch)
                        while let event = try await session.next() {
                            if case let .state(snapshot) = event { sink.yield(.snapshot(snapshot)) }
                        }
                    }
                    sink.yield(.disconnected("daemon closed the connection"))
                } catch {
                    sink.yield(.disconnected("\(error)"))
                }
                try? await Task.sleep(for: .seconds(1))
            }
            sink.finish()
        }
        sink.onTermination = { _ in watcher.cancel() }
        return stream
    }
}
