import Testing

@testable import BerthBar
@testable import BerthCore

@Suite
struct PairCopyTests {
    @Test
    func `connected names the serial and the model`() {
        #expect(PairCopy.connected(.mock(serial: "192.168.4.29:41234", model: "SM_S901B")) == "Connected 192.168.4.29:41234 SM_S901B")
    }

    @Test
    func `connected leaves the model out when adb gave none`() {
        #expect(PairCopy.connected(.mock(serial: "192.168.4.29:41234", model: nil)) == "Connected 192.168.4.29:41234")
    }
}
