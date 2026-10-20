import Foundation

@MainActor
protocol MirrorLauncher {
    func launch(
        executable: String,
        arguments: [String],
        log: URL,
        onExit: @escaping @MainActor @Sendable (Int32) -> Void
    ) throws -> any MirrorProcess
}
