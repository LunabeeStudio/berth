import BerthCore

protocol DaemonActions: Sendable {
    func claim(_ request: ClaimRequest) async throws
    func prepare(_ request: PrepareRequest) async throws
    func release(serial: String) async throws
}
