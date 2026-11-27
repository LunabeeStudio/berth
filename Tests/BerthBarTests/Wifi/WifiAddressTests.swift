import Testing

@testable import BerthBar

@Suite
struct WifiAddressTests {
    @Test
    func `reads the address from the inet line without its prefix length`() {
        let output: String = """
        32: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 3000
            inet 192.168.4.29/24 brd 192.168.4.255 scope global dynamic wlan0
               valid_lft 67353sec preferred_lft 67353sec
        """

        #expect(WifiAddress.parse(ipAddr: output) == "192.168.4.29")
    }

    @Test
    func `no inet line means no address`() {
        let output: String = """
        32: wlan0: <BROADCAST,MULTICAST> mtu 1500 qdisc mq state DOWN group default qlen 3000
        """

        #expect(WifiAddress.parse(ipAddr: output) == nil)
    }

    @Test
    func `empty output means no address`() {
        #expect(WifiAddress.parse(ipAddr: "") == nil)
    }
}
