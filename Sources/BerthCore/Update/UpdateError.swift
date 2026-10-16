public enum UpdateError: Error, CustomStringConvertible, Equatable {
    case devBuild
    case invalidTag(String)
    case missingAsset(String)
    case checksumMalformed
    case checksumMismatch(expected: String, actual: String)
    case extractionFailed(String)
    case notWritable(String)

    public var description: String {
        switch self {
        case .devBuild: "dev build cannot be updated"
        case let .invalidTag(tag): "latest release tag '\(tag)' is not a version"
        case let .missingAsset(name): "latest release has no asset \(name)"
        case .checksumMalformed: "checksum file is malformed"
        case let .checksumMismatch(expected, actual): "checksum mismatch: expected \(expected), got \(actual)"
        case let .extractionFailed(detail): "cannot extract archive: \(detail)"
        case let .notWritable(directory): "install directory is not writable: \(directory)"
        }
    }
}
