import BerthCore

protocol CommandRunner: Sendable {
    func run(_ executable: String, _ arguments: [String], timeout: Duration) async throws -> ShellResult
}
