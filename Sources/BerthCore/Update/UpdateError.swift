import Foundation

public enum UpdateError: Error, LocalizedError, Equatable {
    case devBuild
    case homebrew
    case http(status: Int, url: String)
    case invalidTag(String)
    case missingAsset(String)
    case checksumMalformed
    case checksumMismatch(expected: String, actual: String)
    case extractionFailed(String)
    case notWritable(String)

    public var errorDescription: String? {
        switch self {
        case .devBuild: "dev build cannot be updated"
        case .homebrew: "installed by Homebrew, run brew upgrade berth"
        case let .http(status, url): "HTTP \(status) from \(url)"
        case let .invalidTag(tag): "latest release tag '\(tag)' is not a version"
        case let .missingAsset(name): "latest release has no asset \(name)"
        case .checksumMalformed: "checksum file is malformed"
        case let .checksumMismatch(expected, actual): "checksum mismatch: expected \(expected), got \(actual)"
        case let .extractionFailed(detail): "cannot extract archive: \(detail)"
        case let .notWritable(directory): "install directory is not writable: \(directory)"
        }
    }
}
