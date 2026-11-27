import BerthCore

extension PhysicalDevice {
    var isWifi: Bool {
        Self.isIPAddressWithPort(serial) || serial.contains("._adb-tls-connect._tcp")
    }

    private static func isIPAddressWithPort(_ serial: String) -> Bool {
        let parts: [Substring] = serial.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, isDigits(parts[1]) else { return false }
        let octets: [Substring] = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        return octets.count == 4 && octets.allSatisfy(isDigits)
    }

    private static func isDigits(_ text: Substring) -> Bool {
        !text.isEmpty && text.allSatisfy(\.isASCII) && text.allSatisfy(\.isNumber)
    }
}
