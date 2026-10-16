public enum UpdateCheck: Sendable {
    case upToDate(current: SemanticVersion, latest: SemanticVersion)
    case available(current: SemanticVersion, latest: SemanticVersion, release: Release)
}
