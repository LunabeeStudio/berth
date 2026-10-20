import BerthCore
import Foundation

struct SpawnMirrorLauncher: AndroidMirrorLauncher {
    func launch(executable: String, arguments: [String], log: URL, environment: [String: String]) throws {
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Spawn.detached(executable, arguments, log: log, environment: environment)
    }
}
