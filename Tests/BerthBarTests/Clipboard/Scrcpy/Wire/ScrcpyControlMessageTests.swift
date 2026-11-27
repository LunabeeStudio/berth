import Testing

@testable import BerthBar

@Suite
struct ScrcpyControlMessageTests {
    @Test
    func `get clipboard encodes the type byte and the none copy key`() {
        #expect(ScrcpyControlMessage.getClipboard.bytes == [8, 0])
    }
}
