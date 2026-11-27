protocol ScrcpyServer: Sendable {
    func failureLine() -> String?

    /// - Returns: false when the server had to be terminated, so its process on the device may still run.
    func stop() async -> Bool
}
