import CryptoKit
import Foundation

struct Installer: Sendable {
    let executablePath: String

    func install(_ release: Release) async throws {
        let executable: URL = .init(fileURLWithPath: executablePath)
        let directory: URL = executable.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: directory.path) else {
            throw UpdateError.notWritable(directory.path)
        }
        guard let archive = release.asset(named: Updater.archiveName) else {
            throw UpdateError.missingAsset(Updater.archiveName)
        }
        guard let checksum = release.asset(named: Updater.archiveName + ".sha256") else {
            throw UpdateError.missingAsset(Updater.archiveName + ".sha256")
        }

        let staging: URL = directory.appending(path: ".berth-update-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: staging) }

        let archiveData: Data = try await Download.data(from: archive.browserDownloadUrl)
        let checksumData: Data = try await Download.data(from: checksum.browserDownloadUrl)
        try verify(archiveData, against: checksumData)

        let archiveFile: URL = staging.appending(path: Updater.archiveName)
        let extracted: URL = staging.appending(path: "extracted", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: false)
        try archiveData.write(to: archiveFile)
        let result: ShellResult = try await Shell.run("/usr/bin/tar", ["-xzf", archiveFile.path, "-C", extracted.path])
        guard result.succeeded else { throw UpdateError.extractionFailed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)) }

        let name: String = executable.lastPathComponent
        let siblingBar: URL = directory.appending(path: "berth-bar")
        var replacements: [(source: URL, target: URL)] = [(extracted.appending(path: "berth"), executable)]
        if FileManager.default.fileExists(atPath: siblingBar.path) {
            replacements.append((extracted.appending(path: "berth-bar"), siblingBar))
        }
        for replacement in replacements {
            guard FileManager.default.fileExists(atPath: replacement.source.path) else {
                throw UpdateError.extractionFailed("archive has no \(replacement.source.lastPathComponent) (installing over \(name))")
            }
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: replacement.source.path)
        }
        for replacement in replacements {
            guard rename(replacement.source.path, replacement.target.path) == 0 else {
                throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: replacement.target.path])
            }
        }
    }

    private func verify(_ archive: Data, against checksumFile: Data) throws {
        guard
            let text = String(data: checksumFile, encoding: .utf8),
            let expected = text.split(whereSeparator: \.isWhitespace).first
        else {
            throw UpdateError.checksumMalformed
        }
        let actual: String = SHA256.hash(data: archive).map { String(format: "%02x", $0) }.joined()
        guard actual == expected.lowercased() else {
            throw UpdateError.checksumMismatch(expected: String(expected), actual: actual)
        }
    }
}
