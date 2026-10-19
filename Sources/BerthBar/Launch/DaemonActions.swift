import BerthCore

protocol DaemonActions: Sendable {
    func claim(_ request: ClaimRequest) async throws
    func release(serial: String) async throws
}
