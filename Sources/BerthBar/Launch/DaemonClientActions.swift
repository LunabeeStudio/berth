import BerthCore

struct DaemonClientActions: DaemonActions {
    func claim(_ request: ClaimRequest) async throws {
        _ = try await DaemonClient.claim(request, autoSpawn: false)
    }

    func release(serial: String) async throws {
        _ = try await DaemonClient.call(.release(target: serial), autoSpawn: false)
    }
}
