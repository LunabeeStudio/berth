import Foundation

@MainActor
protocol AndroidMirrorLauncher {
    func launch(executable: String, arguments: [String], log: URL, environment: [String: String]) throws
}
