import Testing

@testable import BerthBar

@Suite
struct MdnsServiceTests {
    @Test
    func `an address splits into its host`() {
        #expect(MdnsService.host(ofAddress: "192.168.4.29:37045") == "192.168.4.29")
        #expect(MdnsService(name: "x", kind: .connect, address: "10.0.0.2:41234").host == "10.0.0.2")
    }
}
