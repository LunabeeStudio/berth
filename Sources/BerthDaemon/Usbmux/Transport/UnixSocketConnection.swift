import Darwin
import Foundation

final class UnixSocketConnection: UsbmuxConnection {
    private let descriptor: Int32

    init(path: String, timeout: Duration) throws {
        let descriptor: Int32 = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw UsbmuxError.unavailable }
        self.descriptor = descriptor
        try Self.configure(descriptor, timeout: timeout)
        try Self.connect(descriptor, to: path)
    }

    deinit {
        close(descriptor)
    }

    func send(_ data: Data) throws {
        var sent: Int = 0
        while sent < data.count {
            let written: Int = data.withUnsafeBytes { buffer in
                write(descriptor, buffer.baseAddress?.advanced(by: sent), data.count - sent)
            }
            guard written > 0 else { throw Self.failure(errno: errno, bytes: written) }
            sent += written
        }
    }

    func receive(count: Int) throws -> Data {
        var received: Data = .init()
        var chunk: [UInt8] = .init(repeating: 0, count: count)
        while received.count < count {
            let bytesRead: Int = chunk.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, count - received.count) }
            guard bytesRead > 0 else { throw Self.failure(errno: errno, bytes: bytesRead) }
            received.append(contentsOf: chunk[..<bytesRead])
        }
        return received
    }
}

private extension UnixSocketConnection {
    static func configure(_ descriptor: Int32, timeout: Duration) throws {
        let components: (seconds: Int64, attoseconds: Int64) = timeout.components
        let limit: timeval = .init(tv_sec: Int(components.seconds), tv_usec: Int32(components.attoseconds / 1_000_000_000_000))
        try set(SO_RCVTIMEO, limit, on: descriptor)
        try set(SO_SNDTIMEO, limit, on: descriptor)
        try set(SO_NOSIGPIPE, Int32(1), on: descriptor)
    }

    static func set<Value>(_ option: Int32, _ value: Value, on descriptor: Int32) throws {
        let result: Int32 = withUnsafeBytes(of: value) { setsockopt(descriptor, SOL_SOCKET, option, $0.baseAddress, socklen_t($0.count)) }
        guard result == 0 else { throw UsbmuxError.unavailable }
    }

    static func connect(_ descriptor: Int32, to path: String) throws {
        var address: sockaddr_un = .init()
        address.sun_family = sa_family_t(AF_UNIX)
        let capacity: Int = MemoryLayout.size(ofValue: address.sun_path)
        guard path.utf8.count < capacity else { throw UsbmuxError.unavailable }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: path.utf8)
            buffer[path.utf8.count] = 0
        }
        let result: Int32 = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else { throw UsbmuxError.unavailable }
    }

    static func failure(errno code: Int32, bytes: Int) -> UsbmuxError {
        if bytes == 0 { return .closed }
        return code == EAGAIN || code == EWOULDBLOCK ? .timedOut : .closed
    }
}
