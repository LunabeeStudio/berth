struct ProcessKillRule: DeviceCommandRule {
    func verdict(for command: SimpleCommand, environment: [String: String]) -> GuardVerdict? {
        guard let name = command.name, name == "pkill" || name == "killall" else { return nil }
        let mentionsDevice: Bool = command.arguments.contains { argument in
            ["emulator", "qemu", "simulator"].contains { argument.lowercased().contains($0) }
        }
        guard mentionsDevice else { return .allow }
        return .deny("berth: killing emulator or simulator processes breaks other agents' leases. Use berth release or berth stop-all.")
    }
}
