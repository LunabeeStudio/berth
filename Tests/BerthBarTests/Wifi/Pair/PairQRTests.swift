import Testing

@testable import BerthBar

@Suite
struct PairQRTests {
    @Test
    func `the payload is the adb wifi qr string`() {
        #expect(PairQR(name: "berth-ab12", password: "s3cret").payload == "WIFI:T:ADB;S:berth-ab12;P:s3cret;;")
    }

    @Test
    func `a random qr has a berth name, a password and needs no payload escaping`() {
        let qr: PairQR = .random()

        #expect(qr.name.hasPrefix("berth-"))
        #expect(qr.name.count == "berth-".count + 8)
        #expect(qr.password.count == 12)
        #expect(!(qr.name + qr.password).contains { ";,:\\\"".contains($0) })
        #expect(PairQR.random() != qr)
    }
}
