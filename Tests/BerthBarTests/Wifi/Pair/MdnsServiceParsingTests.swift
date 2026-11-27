import Testing

@testable import BerthBar

@Suite
struct MdnsServiceParsingTests {
    @Test
    func `parses pairing and connect services`() {
        let output: String = """
        List of discovered mdns services
        adb-R3CT312YV5B-AbCdEf\t_adb-tls-connect._tcp.\t192.168.4.29:41234
        berth-x7k2\t_adb-tls-pairing._tcp.\t192.168.4.29:37045
        """

        #expect(MdnsService.parse(adbMdnsServices: output) == [
            MdnsService(name: "adb-R3CT312YV5B-AbCdEf", kind: .connect, address: "192.168.4.29:41234"),
            MdnsService(name: "berth-x7k2", kind: .pairing, address: "192.168.4.29:37045")
        ])
    }

    @Test
    func `accepts a service type without its trailing dot`() {
        let output: String = "berth-x7k2 _adb-tls-pairing._tcp 192.168.4.29:37045"

        #expect(MdnsService.parse(adbMdnsServices: output).map(\.kind) == [.pairing])
    }

    @Test
    func `only the header means no service`() {
        #expect(MdnsService.parse(adbMdnsServices: "List of discovered mdns services\n\n").isEmpty)
    }

    @Test
    func `skips other service types and malformed lines`() {
        let output: String = """
        List of discovered mdns services
        printer\t_ipp._tcp.\t192.168.4.50:631
        adb-EMULATOR36X3X10X0\t_adb._tcp\t10.0.2.16:5555
        broken line
        """

        #expect(MdnsService.parse(adbMdnsServices: output).isEmpty)
    }
}
