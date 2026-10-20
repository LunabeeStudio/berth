import Testing

@testable import BerthCore

@Suite
struct DeviceHubURLTests {
    @Test
    func `builds the open url for a udid`() {
        #expect(DeviceHubURL.open(udid: "UDID-1")?.absoluteString == "devices://device/open?id=UDID-1")
    }
}
