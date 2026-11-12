import Foundation

extension LaunchAgent {
    public static let bar: LaunchAgent = .init(label: "com.berth.bar")

    public func writeBar(executable: String, environment: [String: String]) throws {
        try write(barPlist(executable: executable, environment: environment))
    }

    func barPlist(executable: String, environment: [String: String]) -> [String: Any] {
        var contents: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
            "ProcessType": "Interactive",
        ]
        if let home = environment[Paths.homeVariable], !home.isEmpty {
            contents["EnvironmentVariables"] = [Paths.homeVariable: home]
        }
        return contents
    }
}
