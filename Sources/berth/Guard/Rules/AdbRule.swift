struct AdbRule: DeviceCommandRule {
    private static let untargeted: Set<String> = ["devices", "version", "help", "start-server"]

    func verdict(for command: SimpleCommand, environment: [String: String]) -> GuardVerdict? {
        guard command.name == "adb" else { return nil }
        var targeted: Bool = environment["ANDROID_SERIAL"] != nil
        var rest: ArraySlice<String> = command.arguments[...]
        while let option = rest.first, option.hasPrefix("-") {
            rest = rest.dropFirst()
            switch option {
            case "-s", "-t":
                targeted = true
                rest = rest.dropFirst()
            case "-d":
                targeted = true
            case "-H", "-P", "-L":
                rest = rest.dropFirst()
            case "--version", "-h", "--help":
                return .allow
            default:
                continue
            }
        }
        let subcommand: String? = rest.first
        if subcommand == "kill-server" {
            return .deny("berth: adb kill-server cuts every agent's emulator. Leave emulators to berth: berth claim, berth release, berth stop-all.")
        }
        if subcommand == "emu", rest.dropFirst().first == "kill" {
            return .deny("berth: adb emu kill stops an emulator berth manages. Use berth release, or berth stop-all.")
        }
        if let subcommand, !Self.untargeted.contains(subcommand), !targeted {
            return .deny("berth: adb without -s targets whatever device is connected. Claim one: berth run -- <cmd>, or SERIAL=$(berth claim) then adb -s \"$SERIAL\" …")
        }
        return .allow
    }
}
