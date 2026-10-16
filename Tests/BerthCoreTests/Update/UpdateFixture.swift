import CryptoKit
import Foundation

@testable import BerthCore

struct UpdateFixture {
    let root: URL
    let installDirectory: URL
    let feed: URL

    var berth: URL { installDirectory.appending(path: "berth") }
    var berthBar: URL { installDirectory.appending(path: "berth-bar") }

    init(tag: String, withBar: Bool = true, corruptChecksum: Bool = false) async throws {
        root = FileManager.default.temporaryDirectory.appending(path: "berth-update-\(UUID().uuidString)", directoryHint: .isDirectory)
        installDirectory = root.appending(path: "install", directoryHint: .isDirectory)
        let content: URL = root.appending(path: "content", directoryHint: .isDirectory)
        let server: URL = root.appending(path: "server", directoryHint: .isDirectory)
        for directory in [installDirectory, content, server] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try Data("new berth".utf8).write(to: content.appending(path: "berth"))
        try Data("new bar".utf8).write(to: content.appending(path: "berth-bar"))
        try Data("old berth".utf8).write(to: installDirectory.appending(path: "berth"))
        if withBar { try Data("old bar".utf8).write(to: installDirectory.appending(path: "berth-bar")) }

        let archive: URL = server.appending(path: Updater.archiveName)
        _ = try await Shell.run("/usr/bin/tar", ["-czf", archive.path, "-C", content.path, "berth", "berth-bar"])
        let digest: String = corruptChecksum
            ? String(repeating: "0", count: 64)
            : SHA256.hash(data: try Data(contentsOf: archive)).map { String(format: "%02x", $0) }.joined()
        let checksum: URL = server.appending(path: Updater.archiveName + ".sha256")
        try Data("\(digest)  \(Updater.archiveName)\n".utf8).write(to: checksum)

        let json: String = """
        {"tag_name": "\(tag)", "assets": [
          {"name": "\(Updater.archiveName)", "browser_download_url": "\(archive.absoluteString)"},
          {"name": "\(Updater.archiveName).sha256", "browser_download_url": "\(checksum.absoluteString)"}
        ]}
        """
        feed = server.appending(path: "latest.json")
        try Data(json.utf8).write(to: feed)
    }

    func updater(current: String) -> Updater {
        .init(feed: feed, currentVersion: current, executablePath: berth.path)
    }

    func read(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func cleanUp() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installDirectory.path)
        try? FileManager.default.removeItem(at: root)
    }
}
