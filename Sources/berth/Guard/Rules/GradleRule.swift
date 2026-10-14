struct GradleRule: DeviceCommandRule {
    private static let valueOptions: Set<String> = ["--tests", "-p", "--project-dir", "-x", "--exclude-task"]

    func verdict(for command: SimpleCommand, environment: [String: String]) -> GuardVerdict? {
        guard let name = command.name, name == "gradle" || name == "gradlew" else { return nil }
        guard environment["ANDROID_SERIAL"] == nil else { return .allow }
        var tasks: [String] = []
        var arguments: IndexingIterator<[String]> = command.arguments.makeIterator()
        while let argument = arguments.next() {
            if Self.valueOptions.contains(argument) {
                _ = arguments.next()
            } else if !argument.hasPrefix("-") {
                tasks.append(argument)
            }
        }
        let touchesDevices: Bool = tasks.contains { task in
            guard let last = task.split(separator: ":").last else { return false }
            return last.hasPrefix("connected") || (last.hasPrefix("install") && last != "installDist")
        }
        guard touchesDevices else { return .allow }
        return .deny("berth: Gradle connected/install tasks hit every connected device. Run berth run -- ./gradlew …")
    }
}
