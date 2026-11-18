import Foundation
import NIOCore
@testable import NIOPosix
import Testing

@testable import BerthDaemon

@Suite
struct AcceptErrorFilterTests {
    @Test
    func `a failed accept does not end the accept sequence and later connections still arrive`() async throws {
        let path: String = "/tmp/berth-accept-\(UUID().uuidString.prefix(8)).sock"
        defer { try? FileManager.default.removeItem(atPath: path) }
        let server: NIOAsyncChannel<NIOAsyncChannel<ByteBuffer, ByteBuffer>, Never> = try await Server.bind(socketPath: path)

        server.channel.pipeline.fireErrorCaught(NIOFcntlFailedError())
        let client: any Channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .connect(unixDomainSocketPath: path)
            .get()

        let accepted: Bool = try await server.executeThenClose { connections in
            var iterator: NIOAsyncChannelInboundStream<NIOAsyncChannel<ByteBuffer, ByteBuffer>>.AsyncIterator = connections.makeAsyncIterator()
            guard let connection = try await iterator.next() else { return false }
            try await connection.executeThenClose { _, _ in }
            return true
        }
        try? await client.close()

        #expect(accepted)
    }
}
