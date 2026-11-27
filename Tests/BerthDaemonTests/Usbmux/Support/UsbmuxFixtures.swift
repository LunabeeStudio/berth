import Foundation

enum UsbmuxFixtures {
    static let udid: String = "00008030-001A2B3C4D5E802E"

    static func plist(_ body: String) -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>\(body)</dict></plist>
        """.utf8)
    }

    static let deviceList: Data = plist("""
    <key>DeviceList</key><array>
      <dict><key>DeviceID</key><integer>7</integer><key>MessageType</key><string>Attached</string>
        <key>Properties</key><dict><key>ConnectionType</key><string>USB</string><key>ProductID</key><integer>4776</integer>
          <key>SerialNumber</key><string>\(udid)</string></dict></dict>
      <dict><key>DeviceID</key><integer>9</integer><key>MessageType</key><string>Attached</string>
        <key>Properties</key><dict><key>ConnectionType</key><string>Network</string>
          <key>SerialNumber</key><string>00008101-000A1B2C3D4E001E</string></dict></dict>
    </array>
    """)

    static func result(_ code: Int) -> Data {
        plist("<key>MessageType</key><string>Result</string><key>Number</key><integer>\(code)</integer>")
    }

    static let pairRecord: Data = plist("<key>PairRecordData</key><data>AAECAw==</data>")

    static func value(_ value: String) -> Data {
        plist("<key>Request</key><string>GetValue</string><key>Value</key><string>\(value)</string>")
    }

    static let lockdownError: Data = plist("<key>Error</key><string>InvalidKey</string><key>Request</key><string>GetValue</string>")
}
