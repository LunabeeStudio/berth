struct ScrcpyRule: DeviceCommandRule {
    func verdict(for command: SimpleCommand, environment: [String: String]) -> GuardVerdict? {
        guard command.name == "scrcpy" else { return nil }
        let inspectOnly: Bool = command.arguments.contains { ["--version", "-v", "--help", "-h"].contains($0) }
        guard !inspectOnly else { return .allow }
        return .deny("berth: scrcpy uses the adb on PATH and can restart the adb server shared with other agents. Use berth mirror <serial> on a leased device.")
    }
}
