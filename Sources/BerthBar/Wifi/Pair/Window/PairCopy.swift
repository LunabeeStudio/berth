import BerthCore

enum PairCopy {
    static let windowTitle: String = "Pair device over Wi-Fi"
    static let notFound: String = "Phone not found: same Wi-Fi network? Try the pairing code."
    static let qrSteps: String = "On the phone: Developer options → Wireless debugging → Pair device with QR code"

    static func connected(_ device: PhysicalDevice) -> String {
        (["Connected", device.serial] + [device.model].compactMap { $0 }).joined(separator: " ")
    }
}
