struct EmulatorRule: DeviceCommandRule {
    func verdict(for command: SimpleCommand, environment: [String: String]) -> GuardVerdict? {
        guard let name = command.name, name == "emulator" || name.hasPrefix("qemu-system-") else { return nil }
        let inspectOnly: Bool = command.arguments.contains { ["-list-avds", "-version", "-accel-check"].contains($0) || $0.hasPrefix("-help") }
        guard !inspectOnly else { return .allow }
        return .deny("berth: berth starts and stops emulators itself. Use berth claim / berth release / berth stop-all, or berth run -- <cmd>.")
    }
}
