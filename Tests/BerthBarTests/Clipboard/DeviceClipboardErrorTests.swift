import BerthCore
import Testing

@testable import BerthBar

@Suite
struct DeviceClipboardErrorTests {
    @Test
    func `a missing scrcpy reads like the mirror message`() {
        #expect("\(DeviceClipboardError.scrcpyNotFound)" == ScrcpyMirror.notFoundMessage)
    }

    @Test
    func `a timeout names the serial`() {
        #expect("\(DeviceClipboardError.timedOut(serial: "R3CT312YV5B"))" == "R3CT312YV5B: clipboard read timed out")
    }

    @Test
    func `a failure carries adb's own line`() {
        #expect("\(DeviceClipboardError.failed(line: "error: device 'x' not found"))" == "error: device 'x' not found")
    }
}
