protocol DeviceClipboard: Sendable {
    /// - Returns: the clipboard text, or nil when the clipboard is empty or holds something that is not text.
    func text(serial: String) async throws -> String?
}
