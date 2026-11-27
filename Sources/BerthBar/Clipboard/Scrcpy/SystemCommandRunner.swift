import BerthCore

struct SystemCommandRunner: CommandRunner {
    func run(_ executable: String, _ arguments: [String], timeout: Duration) async throws -> ShellResult {
        try await Shell.run(executable, arguments, timeout: timeout)
    }
}
