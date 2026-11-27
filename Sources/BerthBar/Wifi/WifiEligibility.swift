import BerthCore

enum WifiEligibility {
    static func showsDisconnectButton(_ device: PhysicalDevice) -> Bool {
        device.isWifi
    }

    static func showsSwitchToWifiButton(_ device: PhysicalDevice) -> Bool {
        !KillEligibility.showsKillButton(device) && !device.isWifi && device.state == .device
    }
}
