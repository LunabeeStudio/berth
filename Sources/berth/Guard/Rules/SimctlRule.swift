struct SimctlRule: DeviceCommandRule {
    private static let lifecycle: Set<String> = ["boot", "shutdown", "erase", "delete", "create", "clone"]
    private static let deviceFree: Set<String> = ["list", "help"]

    func verdict(for command: SimpleCommand, environment: [String: String]) -> GuardVerdict? {
        guard command.name == "simctl" else { return nil }
        let subcommand: String? = command.arguments.first { !$0.hasPrefix("-") }
        if let subcommand, Self.lifecycle.contains(subcommand) {
            return .deny("berth: simctl \(subcommand) changes simulators outside your lease. Claim one: berth run --ios -- sh -c 'xcrun simctl install \"$SIMULATOR_UDID\" …', or UDID=$(berth claim --ios).")
        }
        if command.arguments.contains("booted"), !Self.deviceFree.contains(subcommand ?? "") {
            return .deny("berth: simctl booted can hit another agent's simulator. Claim one: berth run --ios -- sh -c 'xcrun simctl install \"$SIMULATOR_UDID\" …', or UDID=$(berth claim --ios).")
        }
        return .allow
    }
}
