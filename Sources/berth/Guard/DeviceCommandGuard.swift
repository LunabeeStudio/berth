struct DeviceCommandGuard {
    static let defaultRules: [any DeviceCommandRule] = [
        AdbRule(), EmulatorRule(), SimctlRule(), XcodebuildRule(), GradleRule(), ProcessKillRule(), ScrcpyRule(),
    ]
    private static let shells: Set<String> = ["sh", "bash", "zsh"]

    let environment: [String: String]
    let rules: [any DeviceCommandRule]

    init(environment: [String: String], rules: [any DeviceCommandRule] = DeviceCommandGuard.defaultRules) {
        self.environment = environment
        self.rules = rules
    }

    private static func script(in arguments: [String]) -> String? {
        guard let flag = arguments.firstIndex(where: { $0.hasPrefix("-") && !$0.hasPrefix("--") && $0.contains("c") }) else { return nil }
        return arguments.indices.contains(flag + 1) ? arguments[flag + 1] : nil
    }

    func verdict(for line: String) -> GuardVerdict {
        guard let commands = ShellTokenizer.commands(of: line) else { return .allow }
        var environment: [String: String] = environment
        for (position, shellCommand) in commands.enumerated() {
            let command: SimpleCommand = .init(words: shellCommand.words)
            let scoped: [String: String] = environment.merging(command.assignments) { $1 }
            guard let name = command.name else {
                environment = scoped
                continue
            }
            if name == "export" {
                environment.merge(command.arguments.compactMap(SimpleCommand.assignment)) { $1 }
                continue
            }
            let piped: String? = shellCommand.isPiped && position > 0 ? commands[position - 1].heredoc : nil
            let stdin: String? = shellCommand.heredoc ?? piped
            if case let .deny(reason) = verdict(for: command, name: name, stdin: stdin, environment: scoped) { return .deny(reason) }
        }
        return .allow
    }

    private func verdict(for command: SimpleCommand, name: String, stdin: String?, environment: [String: String]) -> GuardVerdict {
        if name == "berth" { return .allow }
        if Self.shells.contains(name), let script = Self.script(in: command.arguments) ?? stdin {
            return DeviceCommandGuard(environment: environment, rules: rules).verdict(for: script)
        }
        return rules.lazy.compactMap { $0.verdict(for: command, environment: environment) }.first ?? .allow
    }
}
