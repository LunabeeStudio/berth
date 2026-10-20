import BerthCore
import Foundation

@MainActor
struct SpawnMirrorLauncher: AndroidMirrorLauncher {
    func launch(executable: String, arguments: [String], log: URL, environment: [String: String]) throws {
        try ScrcpyMirror.prepareLogDirectory(of: log)
        try Spawn.detached(executable, arguments, log: log, environment: environment)
    }
}
