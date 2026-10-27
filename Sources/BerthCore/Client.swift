import Foundation
import NIOCore
import NIOPosix

public enum ClientError: Error, CustomStringConvertible {
    case daemonUnavailable(String)
    case connectionClosed
    case timedOut
    case rejected(String)
    case unexpected(Event)

    public var description: String {
        switch self {
        case let .daemonUnavailable(reason): "berth daemon unavailable: \(reason)"
        case .connectionClosed: "berth daemon closed the connection"
        case .timedOut: "timed out waiting for an emulator"
        case let .rejected(message): message
        case let .unexpected(event): "unexpected reply from daemon: \(event)"
        }
    }
}

public final class DaemonSession {
    private var inbound: NIOAsyncChannelInboundStream<ByteBuffer>.AsyncIterator
    private let outbound: NIOAsyncChannelOutboundWriter<ByteBuffer>
    private let channel: Channel
    private let timeoutFlag = TimeoutFlag()

    init(inbound: NIOAsyncChannelInboundStream<ByteBuffer>, outbound: NIOAsyncChannelOutboundWriter<ByteBuffer>, channel: Channel) {
        self.inbound = inbound.makeAsyncIterator()
        self.outbound = outbound
        self.channel = channel
    }

    public func send(_ request: Request) async throws {
        try await outbound.write(Wire.line(request))
    }

    public func next() async throws -> Event? {
        do {
            guard let line = try await inbound.next() else { return nil }
            return try Wire.decode(Event.self, from: line)
        } catch where timeoutFlag.isSet {
            throw ClientError.timedOut
        }
    }

    public func closeAfter(_ timeout: Duration) -> Task<Void, Never> {
        let channel = channel
        let flag = timeoutFlag
        return Task {
            guard (try? await Task.sleep(for: timeout)) != nil else { return }
            flag.set()
            channel.close(promise: nil)
        }
    }

    public var didTimeOut: Bool { timeoutFlag.isSet }

    public func request(_ request: Request) async throws -> Event {
        try await send(request)
        guard let event = try await next() else { throw ClientError.connectionClosed }
        return event
    }
}

public enum DaemonClient {
    public static func withSession<Result: Sendable>(
        autoSpawn: Bool = true,
        _ body: (DaemonSession) async throws -> Result
    ) async throws -> Result {
        let channel = try await connect(autoSpawn: autoSpawn)
        return try await channel.executeThenClose { inbound, outbound in
            try await body(DaemonSession(inbound: inbound, outbound: outbound, channel: channel.channel))
        }
    }

    @discardableResult
    public static func call(_ request: Request, autoSpawn: Bool = true) async throws -> Event {
        let event = try await withSession(autoSpawn: autoSpawn) { try await $0.request(request) }
        if case let .failure(message) = event { throw ClientError.rejected(message) }
        return event
    }

    /// Queues `request`, waits for the grant and acknowledges it.
    /// - Parameters:
    ///   - timeout: closes the connection after this long when set.
    ///   - onQueued: called with the queue position each time it changes.
    ///   - onNotice: called with each notice the daemon sends while the claim waits.
    public static func claim(
        _ request: ClaimRequest,
        autoSpawn: Bool = true,
        timeout: Duration? = nil,
        onQueued: (Int) -> Void = { _ in },
        onNotice: (String) -> Void = { _ in }
    ) async throws -> Grant {
        try await withSession(autoSpawn: autoSpawn) { session in
            try await session.send(.claim(request))
            let watchdog: Task<Void, Never>? = timeout.map { session.closeAfter($0) }
            defer { watchdog?.cancel() }
            while let event = try await session.next() {
                switch event {
                case let .queued(position):
                    onQueued(position)
                case let .granted(grant):
                    try await session.send(.ack(lease: grant.leaseID))
                    return grant
                case let .failure(message):
                    throw ClientError.rejected(message)
                case let .ok(notice):
                    onNotice(notice)
                case .state:
                    continue
                }
            }
            throw session.didTimeOut ? ClientError.timedOut : ClientError.connectionClosed
        }
    }

    public static func snapshot(autoSpawn: Bool = true) async throws -> StateSnapshot {
        let event = try await call(.status, autoSpawn: autoSpawn)
        guard case let .state(snapshot) = event else { throw ClientError.unexpected(event) }
        return snapshot
    }

    static func connect(autoSpawn: Bool) async throws -> NIOAsyncChannel<ByteBuffer, ByteBuffer> {
        if let channel = try? await connectOnce() { return channel }
        guard autoSpawn else { throw ClientError.daemonUnavailable("not running") }
        try spawnDaemon()
        var lastError: Error?
        for _ in 0..<50 {
            try await Task.sleep(for: .milliseconds(100))
            do { return try await connectOnce() } catch { lastError = error }
        }
        throw ClientError.daemonUnavailable("did not start (\(lastError.map { "\($0)" } ?? "unknown")); see \(Paths.daemonLog.path)")
    }

    static func connectOnce() async throws -> NIOAsyncChannel<ByteBuffer, ByteBuffer> {
        try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .connect(unixDomainSocketPath: Paths.socket.path) { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(NewlineFrameDecoder()))
                    return try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
                }
            }
    }

    static func spawnDaemon() throws {
        try Paths.ensureDirectories()
        let executable = Bundle.main.executablePath ?? CommandLine.arguments[0]
        try Spawn.detached(executable, ["daemon", "run"], log: Paths.daemonLog)
    }
}
