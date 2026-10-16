public protocol UpdateSource: Sendable {
    func check() async throws -> UpdateCheck
    func install(_ release: Release) async throws
}
