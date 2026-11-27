@testable import BerthDaemon
import Foundation
import Testing

@Suite
struct LockdownKeyTests {
    @Test
    func `get value request names the key`() throws {
        let fields: [String: Any] = try PropertyList.dictionary(from: LockdownKey.productType.payload())

        #expect(fields["Request"] as? String == "GetValue")
        #expect(fields["Key"] as? String == "ProductType")
        #expect(fields["Label"] as? String == "berth")
    }

    @Test
    func `a get value reply yields its value`() throws {
        #expect(try LockdownKey.value(in: UsbmuxFixtures.value("iPhone10,6")) == "iPhone10,6")
    }

    @Test
    func `an error reply yields no value`() throws {
        #expect(try LockdownKey.value(in: UsbmuxFixtures.lockdownError) == nil)
    }
}
