public enum UpdateCheck: Sendable {
    case upToDate(current: String, latest: SemanticVersion)
    case available(current: String, release: Release, version: SemanticVersion)
}
