struct XcodebuildRule: DeviceCommandRule {
    func verdict(for command: SimpleCommand, environment: [String: String]) -> GuardVerdict? {
        guard command.name == "xcodebuild" else { return nil }
        let arguments: [String] = command.arguments
        let destinations: [String] = zip(arguments, arguments.dropFirst()).filter { $0.0 == "-destination" }.map(\.1)
        let byName: Bool = destinations.contains { $0.contains("name=") && $0.contains("Simulator") && !$0.contains("id=") }
        guard byName else { return .allow }
        return .deny("berth: xcodebuild -destination by simulator name boots one outside berth. Run berth run --ios -- sh -c 'xcodebuild … -destination \"id=$SIMULATOR_UDID\" …'.")
    }
}
