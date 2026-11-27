enum AdbOutput {
    static func errorLine(stdout: String, stderr: String, status: Int32) -> String {
        (lines(stderr) + lines(stdout)).first ?? "adb exited with status \(status)"
    }

    static func isPaired(stdout: String) -> Bool {
        lines(stdout).contains { $0.hasPrefix("Successfully paired") }
    }

    static func pairedGuid(stdout: String) -> String? {
        guard
            let line = lines(stdout).first(where: { $0.hasPrefix("Successfully paired") }),
            let start = line.firstRange(of: "[guid=")?.upperBound,
            let end = line[start...].firstIndex(of: "]")
        else { return nil }
        return String(line[start ..< end])
    }

    static func isConnected(stdout: String) -> Bool {
        lines(stdout).contains { $0.hasPrefix("connected to") || $0.hasPrefix("already connected to") }
    }

    static func reportsError(stdout: String, stderr: String) -> Bool {
        (lines(stderr) + lines(stdout)).contains { $0.hasPrefix("error:") }
    }

    static func reportsNoSuchDevice(stdout: String, stderr: String) -> Bool {
        (lines(stderr) + lines(stdout)).contains { $0.hasPrefix("error: no such device") }
    }

    private static func lines(_ output: String) -> [String] {
        output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("*") }
    }
}
