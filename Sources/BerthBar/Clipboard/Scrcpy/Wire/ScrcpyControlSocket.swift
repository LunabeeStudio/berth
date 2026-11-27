import Darwin

final class ScrcpyControlSocket: ScrcpyControlChannel {
    private static let chunkSize: Int = 4096

    private let descriptor: Int32

    init?(loopbackPort port: UInt16) {
        let descriptor: Int32 = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return nil }
        var noSigPipe: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        var address: sockaddr_in = .init()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian
        let connected: Int32 = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connected == 0 else {
            Darwin.close(descriptor)
            return nil
        }
        self.descriptor = descriptor
    }

    deinit {
        Darwin.close(descriptor)
    }

    func write(_ bytes: [UInt8]) -> Bool {
        var sent: Int = 0
        while sent < bytes.count {
            let count: Int = bytes[sent...].withUnsafeBytes { Darwin.write(descriptor, $0.baseAddress, $0.count) }
            if count > 0 {
                sent += count
            } else if count < 0, errno == EINTR {
                continue
            } else {
                return false
            }
        }
        return true
    }

    func read(until deadline: ContinuousClock.Instant) -> ScrcpyReadOutcome {
        while true {
            var poller: pollfd = .init(fd: descriptor, events: Int16(POLLIN), revents: 0)
            let ready: Int32 = poll(&poller, 1, Self.milliseconds(until: deadline))
            if ready < 0, errno == EINTR { continue }
            if ready < 0 { return .closed }
            if ready == 0 { return .timeout }
            var buffer: [UInt8] = .init(repeating: 0, count: Self.chunkSize)
            let count: Int = Darwin.read(descriptor, &buffer, buffer.count)
            if count < 0, errno == EINTR { continue }
            return count > 0 ? .bytes(Array(buffer[..<count])) : .closed
        }
    }

    private static func milliseconds(until deadline: ContinuousClock.Instant) -> Int32 {
        let remaining: Duration = ContinuousClock.now.duration(to: deadline)
        guard remaining > .zero else { return 0 }
        let components: (seconds: Int64, attoseconds: Int64) = remaining.components
        return Int32(clamping: components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000)
    }
}
