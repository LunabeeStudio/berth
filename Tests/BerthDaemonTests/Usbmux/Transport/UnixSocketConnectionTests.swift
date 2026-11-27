@testable import BerthDaemon
import Testing

@Suite
struct UnixSocketConnectionTests {
    @Test
    func `a missing socket is unavailable`() {
        #expect(throws: UsbmuxError.unavailable) { try UnixSocketConnection(path: "/nonexistent/usbmuxd", timeout: .milliseconds(500)) }
    }
}
