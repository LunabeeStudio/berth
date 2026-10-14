import BerthCore
import Foundation
import NIOCore
import NIOPosix

struct Server {
    let broker: Broker
    let onShutdown: @Sendable () -> Void

    func run(socketPath: String) async throws {
        let server = try await ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .bind(unixDomainSocketPath: socketPath, cleanupExistingSocketFile: true) { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(NewlineFrameDecoder()))
                    return try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
                }
            }
        chmod(socketPath, 0o600)
        Log.info("listening on \(socketPath)")
        try await withThrowingDiscardingTaskGroup { group in
            try await server.executeThenClose { connections in
                for try await connection in connections {
                    group.addTask { await handle(connection) }
                }
            }
        }
    }

    private func handle(_ connection: NIOAsyncChannel<ByteBuffer, ByteBuffer>) async {
        let conn = UUID()
        let (events, sink) = AsyncStream.makeStream(of: Event.self)
        do {
            try await connection.executeThenClose { inbound, outbound in
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await event in events {
                            try await outbound.write(Wire.line(event))
                        }
                    }
                    for try await line in inbound {
                        await dispatch(line, conn: conn, sink: sink)
                    }
                    await broker.connectionClosed(conn)
                    sink.finish()
                    try await group.waitForAll()
                }
            }
        } catch {
            sink.finish()
        }
        await broker.connectionClosed(conn)
    }

    private func dispatch(_ line: ByteBuffer, conn: UUID, sink: AsyncStream<Event>.Continuation) async {
        let request: Request
        do {
            request = try Wire.decode(Request.self, from: line)
        } catch {
            sink.yield(.failure("malformed request: \(error)"))
            return
        }
        switch request {
        case let .claim(claim):
            await broker.claim(claim, conn: conn, sink: sink)
        case let .ack(lease):
            await broker.acknowledge(lease: lease, conn: conn)
        case let .release(target):
            sink.yield(await broker.release(target))
        case let .renew(target, ttl):
            sink.yield(await broker.renew(target, ttl: ttl))
        case let .stop(target):
            sink.yield(await broker.stop(target))
        case .stopAll:
            sink.yield(await broker.stopAll())
        case .status:
            sink.yield(.state(await broker.snapshot()))
        case .watch:
            await broker.watch(conn: conn, sink: sink)
        case .shutdown:
            sink.yield(.ok("daemon stopping; emulators keep running and are adopted on next start"))
            onShutdown()
        }
    }
}
