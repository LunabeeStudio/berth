protocol DeviceCommandRule: Sendable {
    func verdict(for command: SimpleCommand, environment: [String: String]) -> GuardVerdict?
}
