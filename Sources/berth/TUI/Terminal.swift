import Darwin
import Foundation

enum Key: Sendable {
    case up, down, quit, release, kill, other
}

final class Terminal {
    private var original = termios()

    func enter() {
        tcgetattr(STDIN_FILENO, &original)
        var raw = original
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON | ISIG | IEXTEN)
        raw.c_iflag &= ~tcflag_t(IXON | ICRNL)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        Self.write("\u{1B}[?1049h\u{1B}[?25l")
    }

    func restore() {
        Self.write("\u{1B}[?25h\u{1B}[?1049l")
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
    }

    static func write(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    static var size: (rows: Int, columns: Int) {
        var size = winsize()
        guard ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0, size.ws_col > 0 else { return (24, 100) }
        return (Int(size.ws_row), Int(size.ws_col))
    }

    /// Reads keys on a dedicated thread: `read` blocks, which must not happen on the cooperative pool.
    static func keys() -> AsyncStream<Key> {
        AsyncStream { continuation in
            let thread = Thread {
                var buffer = [UInt8](repeating: 0, count: 16)
                while true {
                    let count = read(STDIN_FILENO, &buffer, buffer.count)
                    guard count > 0 else { continuation.finish(); return }
                    continuation.yield(parse(Array(buffer[0..<count])))
                }
            }
            thread.start()
        }
    }

    private static func parse(_ bytes: [UInt8]) -> Key {
        switch bytes {
        case [0x1B, 0x5B, 0x41], [UInt8(ascii: "k")]: .up
        case [0x1B, 0x5B, 0x42], [UInt8(ascii: "j")]: .down
        case [UInt8(ascii: "q")], [0x03], [0x1B]: .quit
        case [UInt8(ascii: "r")]: .release
        case [UInt8(ascii: "x")]: .kill
        default: .other
        }
    }
}
