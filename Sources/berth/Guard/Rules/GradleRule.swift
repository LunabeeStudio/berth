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
        let leafNames: [Substring] = tasks.compactMap { $0.split(separator: ":").last }
        if leafNames.contains(where: { $0.hasPrefix("install") && $0 != "installDist" }) {
            return .deny("berth: Gradle install tasks can restart the shared adb server and hit every connected device. Run ./gradlew assemble…, then SERIAL=$(berth claim) and adb -s \"$SERIAL\" install -r <apk>.")
        }
        guard leafNames.contains(where: { $0.hasPrefix("connected") }) else { return .allow }
        return .deny("berth: Gradle connected tasks hit every connected device. Run berth run -- ./gradlew …")
    }
}
