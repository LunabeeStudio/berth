import BerthCore
import Foundation

extension LaunchAgent {
    static func temporary(label: String) -> LaunchAgent {
        let directory: URL = FileManager.default.temporaryDirectory
            .appending(path: "berth-bar-login-\(UUID().uuidString)", directoryHint: .isDirectory)
        return .init(label: label, directory: directory)
    }
}
