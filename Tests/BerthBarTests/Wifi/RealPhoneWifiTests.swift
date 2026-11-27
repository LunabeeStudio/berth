import BerthCore
import Foundation
import Testing

@testable import BerthBar

@MainActor
@Suite
struct RealPhoneWifiTests {
    nonisolated private static let usbSerial: String? = ProcessInfo.processInfo.environment["BERTH_WIFI_PHONE"]

    nonisolated private static let mdnsSerial: String? = ProcessInfo.processInfo.environment["BERTH_WIFI_MDNS_SERIAL"]

    @Test(.enabled(if: usbSerial != nil, "set BERTH_WIFI_PHONE=<usb serial> to drive a real phone"))
    func `a usb phone switches to wifi and disconnects through real adb`() async throws {
        let serial: String = try #require(Self.usbSerial)
        let adb: SdkWifiAdb = .init()
        do {
            try await Self.proof(serial: serial, adb: adb)
        } catch {
            await Self.restoreUSB(serial: serial, adb: adb)
            throw error
        }
        await Self.restoreUSB(serial: serial, adb: adb)
    }

    @Test(.enabled(if: mdnsSerial != nil, "set BERTH_WIFI_MDNS_SERIAL=<adb-...._adb-tls-connect._tcp serial of a paired phone> to disconnect it"))
    func `an mdns named wifi device disconnects through real adb`() async throws {
        let serial: String = try #require(Self.mdnsSerial)
        let adb: SdkWifiAdb = .init()
        let actions: WifiDeviceActions = .init(adb: adb)

        await actions.disconnect(serial: serial).value
        print("[wifi-proof] disconnect(\(serial)) caption=\(actions.caption ?? "nil")")
        #expect(actions.caption == nil)

        await actions.disconnect(serial: serial).value
        print("[wifi-proof] second disconnect caption=\(actions.caption ?? "nil")")
        #expect(actions.caption == nil)
        let reconnected: Bool = await Self.comesBack(serial, adb: adb)
        print("[wifi-proof] \(serial) \(reconnected ? "came back within 10 s (mDNS auto-connect)" : "stayed gone for 10 s")")
    }

    private static func proof(serial: String, adb: SdkWifiAdb) async throws {
        let address: String = try #require(try await adb.wifiAddress(serial: serial))
        let wifiSerial: String = "\(address):5555"
        print("[wifi-proof] wifiAddress(\(serial)) = \(address)")
        let actions: WifiDeviceActions = .init(adb: adb)

        await actions.switchToWifi(serial: serial).value
        let listed: [PhysicalDevice] = try await adb.devices()
        print("[wifi-proof] after switch: caption=\(actions.caption ?? "nil") devices=\(listed.map { "\($0.serial)=\($0.state.word)" })")
        #expect(actions.caption == nil)
        #expect(listed.contains { $0.serial == wifiSerial && $0.state == .device && $0.isWifi })
        #expect(listed.contains { $0.serial == serial && $0.state == .device })

        let mdns: ShellResult = try await Shell.run(Config.defaultADBPath(), ["mdns", "services"], timeout: .seconds(15))
        print("[wifi-proof] adb mdns services (status \(mdns.status)):\n\(mdns.stdout)\(mdns.stderr)")
        print("[wifi-proof] parsed: \(MdnsService.parse(adbMdnsServices: mdns.stdout))")

        await actions.disconnect(serial: wifiSerial).value
        print("[wifi-proof] disconnect caption=\(actions.caption ?? "nil")")
        #expect(actions.caption == nil)
        let reconnected: Bool = await comesBack(wifiSerial, adb: adb)
        print("[wifi-proof] \(wifiSerial) \(reconnected ? "came back within 10 s (mDNS auto-connect)" : "stayed gone for 10 s")")
    }

    private static func comesBack(_ wifiSerial: String, adb: SdkWifiAdb) async -> Bool {
        for _ in 1 ... 10 {
            let devices: [PhysicalDevice] = (try? await adb.devices()) ?? []
            if devices.contains(where: { $0.serial == wifiSerial && $0.state == .device }) { return true }
            try? await Task.sleep(for: .seconds(1))
        }
        return false
    }

    private static func restoreUSB(serial: String, adb: SdkWifiAdb) async {
        let usb: ShellResult? = try? await Shell.run(Config.defaultADBPath(), ["-s", serial, "usb"], timeout: .seconds(15))
        print("[wifi-proof] adb -s \(serial) usb -> status \(usb?.status ?? -1) \(usb?.trimmedOutput ?? "")")
        for _ in 1 ... 15 {
            let devices: [PhysicalDevice] = (try? await adb.devices()) ?? []
            if devices.contains(where: { $0.serial == serial && $0.state == .device }) {
                print("[wifi-proof] usb row back: \(devices.map { "\($0.serial)=\($0.state.word)" })")
                return
            }
            try? await Task.sleep(for: .seconds(1))
        }
        print("[wifi-proof] usb row NOT back in state device")
    }
}
